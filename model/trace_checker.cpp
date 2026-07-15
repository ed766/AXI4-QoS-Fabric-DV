#include "fabric_tlm_model.h"

#include <cstdint>
#include <fstream>
#include <iostream>
#include <map>
#include <queue>
#include <regex>
#include <string>
#include <tuple>

static long field(const std::string& line, const std::string& name, long fallback = -1) {
  std::regex pattern("\\\"" + name + "\\\":(-?[0-9]+)");
  std::smatch match;
  return std::regex_search(line, match, pattern) ? std::stol(match[1]) : fallback;
}

static uint64_t hex_field(const std::string& line, const std::string& name) {
  std::regex pattern("\\\"" + name + "\\\":\\\"([0-9a-fA-F]+)\\\"");
  std::smatch match;
  return std::regex_search(line, match, pattern) ? std::stoull(match[1], nullptr, 16) : 0;
}

static std::string event_name(const std::string& line) {
  std::regex pattern("\\\"event\\\":\\\"([^\\\"]+)\\\"");
  std::smatch match;
  return std::regex_search(line, match, pattern) ? match[1].str() : "";
}

struct Request {
  long master, id, target, address, beats, size, legal, response;
};

struct WriteRoute {
  Request request;
  long beat = 0;
};

static uint64_t initial_word(long target, long address) {
  const uint64_t index = (static_cast<uint64_t>(address) - (static_cast<uint64_t>(target) << 28)) >> 3;
  return UINT64_C(0xA500000000000000) ^ index;
}

int sc_main(int argc, char** argv) {
  if (argc != 2) {
    std::cerr << "usage: trace_checker TRACE.jsonl\n";
    return 2;
  }
  std::ifstream input(argv[1]);
  if (!input) {
    std::cerr << "unable to read " << argv[1] << '\n';
    return 2;
  }

  FabricTlmModel model("model");
  using Key = std::tuple<long,long,char>;
  std::map<Key, Request> pending;
  std::map<Key, Request> accepted;
  std::map<std::pair<long,long>, long> read_beats;
  std::queue<WriteRoute> target_writes[4];
  std::queue<WriteRoute> source_routes[4];
  std::queue<std::tuple<long,uint64_t,long>> source_writes[4];
  std::map<std::pair<long,long>, uint64_t> memory;
  unsigned events=0, requests=0, responses=0, grants=0, beats=0, memory_checks=0, errors=0;
  std::string line;
  while (std::getline(input,line)) {
    ++events;
    const auto event=event_name(line);
    const long master=field(line,"master");
    const long id=field(line,"id");
    if (event=="aw" || event=="ar") {
      ++requests;
      Request req{master,id,field(line,"target"),field(line,"address"),field(line,"len"),
                  field(line,"size"),field(line,"legal"),field(line,"legal") ? 0 : 3};
      if(req.legal && req.target==2 && ((req.address>>12)&15)==15) req.response=2;
      const int expected_target=model.decode(req.address);
      if (req.legal && (expected_target < 0 || expected_target != req.target)) ++errors;
      const char kind=event=="aw"?'w':'r';
      const Key key{master,id,kind};
      if (pending.count(key)) ++errors;
      pending[key]=req;
      accepted[key]=req;
      if(kind=='w') source_routes[master].push({req,0});
      if(kind=='r') read_beats[{master,id}]=req.beats;
    } else if (event=="aw_grant" || event=="ar_grant") {
      ++grants;
      const char kind=event=="aw_grant"?'w':'r';
      const Key key{master,id,kind};
      if(!pending.count(key) || pending[key].target!=field(line,"target") || !pending[key].legal) ++errors;
      if(kind=='w' && pending.count(key)) target_writes[field(line,"target")].push({pending[key],0});
    } else if(event=="w") {
      if(source_routes[master].empty()) { ++errors; continue; }
      auto& route=source_routes[master].front();
      const long last=field(line,"last");
      if(last!=(route.beat==route.request.beats-1)) ++errors;
      if(route.request.legal) source_writes[master].push({last,hex_field(line,"data"),field(line,"strb")});
      route.beat++;
      if(last) source_routes[master].pop();
    } else if(event=="target_w") {
      ++beats;
      const long target=field(line,"target");
      if(target<0 || target>3 || target_writes[target].empty()) { ++errors; continue; }
      auto& route=target_writes[target].front();
      if(source_writes[route.request.master].empty()) { ++errors; continue; }
      const auto [source_last,source_data,source_strb]=source_writes[route.request.master].front();
      source_writes[route.request.master].pop();
      const long last=field(line,"last");
      const uint64_t data=hex_field(line,"data");
      const long strb=field(line,"strb");
      if(last!=source_last || data!=source_data || strb!=source_strb || last!=(route.beat==route.request.beats-1)) ++errors;
      const long address=route.request.address + (route.beat << route.request.size);
      const bool write_error=target==2 && ((route.request.address>>12)&15)==15;
      if(!write_error) {
        auto mem_key=std::make_pair(target,address & ~7L);
        uint64_t value=memory.count(mem_key)?memory[mem_key]:initial_word(target,address);
        for(int lane=0;lane<8;lane++) if((strb>>lane)&1) {
          value=(value & ~(UINT64_C(0xff)<<(lane*8))) | (((data>>(lane*8))&0xff)<<(lane*8));
        }
        memory[mem_key]=value;
      }
      route.beat++;
      if(last) target_writes[target].pop();
    } else if (event=="target_b") {
      const Key key{master,id,'w'};
      if(!accepted.count(key) || !accepted[key].legal) ++errors;
    } else if (event=="b") {
      ++responses;
      const Key key{master,id,'w'};
      if (!pending.count(key) || field(line,"resp")!=pending[key].response) ++errors;
      pending.erase(key);
    } else if(event=="target_r") {
      ++beats;
      const Key key{master,id,'r'};
      if(!accepted.count(key) || !accepted[key].legal) ++errors;
      if(accepted.count(key)) {
        auto& req=accepted[key];
        // Source-side R is logged first in a cycle, so the remaining count may already be decremented.
        const long beat=req.beats-read_beats[{master,id}]-1;
        if(field(line,"last")!=(beat==req.beats-1)) ++errors;
        const bool read_error=req.target==2 && ((req.address>>12)&15)==15;
        if(!read_error) {
          const long address=req.address+(beat<<req.size);
          const auto mem_key=std::make_pair(req.target,address & ~7L);
          const uint64_t expected=memory.count(mem_key)?memory[mem_key]:initial_word(req.target,address);
          if(hex_field(line,"data")!=expected) ++errors;
          ++memory_checks;
        }
      }
    } else if (event=="r") {
      const Key key{master,id,'r'};
      if(!pending.count(key)) { ++errors; continue; }
      auto& remaining=read_beats[{master,id}];
      if(remaining<=0 || field(line,"last")!=(remaining==1)) ++errors;
      --remaining;
      if(field(line,"last")==1) {
        ++responses;
        if(field(line,"resp")!=pending[key].response) ++errors;
        pending.erase(key); read_beats.erase({master,id});
      }
    } else if(event=="reset" && field(line,"asserted")==1) {
      pending.clear(); read_beats.clear();
      accepted.clear();
      for(auto& queue:target_writes) while(!queue.empty()) queue.pop();
      for(auto& queue:source_routes) while(!queue.empty()) queue.pop();
      for(auto& queue:source_writes) while(!queue.empty()) queue.pop();
    }
  }
  errors+=pending.size();
  for(const auto& queue:target_writes) errors+=queue.size();
  for(const auto& queue:source_routes) errors+=queue.size();
  for(const auto& queue:source_writes) errors+=queue.size();
  std::cout << "TRACE_RESULT|events=" << events << "|requests=" << requests
            << "|grants=" << grants << "|beats=" << beats << "|responses=" << responses
            << "|memory_checks=" << memory_checks << "|errors=" << errors << '\n';
  return errors ? 1 : 0;
}
