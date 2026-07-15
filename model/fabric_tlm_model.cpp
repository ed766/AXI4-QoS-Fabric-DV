#include "fabric_tlm_model.h"

#include <algorithm>
#include <cstring>
#include <limits>

FabricTlmModel::FabricTlmModel(sc_core::sc_module_name name)
    : sc_core::sc_module(name), socket("socket") {
  socket.register_b_transport(this, &FabricTlmModel::b_transport);
  for (auto& row : allow_) row.fill(true);
  for (unsigned target = 0; target < memory_.size(); ++target) {
    for (unsigned word = 0; word < memory_[target].size(); ++word) {
      memory_[target][word] = 0xA500000000000000ULL ^ word;
    }
  }
}

int FabricTlmModel::decode(std::uint64_t address) const {
  for (unsigned target = 0; target < base_.size(); ++target) {
    if ((address & mask_[target]) == (base_[target] & mask_[target])) return target;
  }
  return -1;
}

unsigned FabricTlmModel::choose(const std::array<bool, 4>& request,
                                const std::array<unsigned, 4>& qos,
                                const std::array<unsigned, 4>& age,
                                unsigned rr_pointer) const {
  for (unsigned offset = 0; offset < request.size(); ++offset) {
    const unsigned candidate = (rr_pointer + offset) % request.size();
    if (request[candidate] && age[candidate] >= 31) return candidate;
  }
  unsigned best_qos = 0;
  for (unsigned master = 0; master < request.size(); ++master) {
    if (request[master]) best_qos = std::max(best_qos, qos[master]);
  }
  for (unsigned offset = 0; offset < request.size(); ++offset) {
    const unsigned candidate = (rr_pointer + offset) % request.size();
    if (request[candidate] && qos[candidate] == best_qos) return candidate;
  }
  return std::numeric_limits<unsigned>::max();
}

void FabricTlmModel::b_transport(tlm::tlm_generic_payload& tx, sc_core::sc_time& delay) {
  auto* attr = tx.get_extension<FabricAttributes>();
  const int target = decode(tx.get_address());
  if (!attr || attr->master >= 4 || target < 0 || !allow_[attr->master][target]
      || (secure_only_[target] && !attr->secure)) {
    tx.set_response_status(tlm::TLM_ADDRESS_ERROR_RESPONSE);
    delay += sc_core::sc_time(2, sc_core::SC_NS);
    return;
  }

  if (tx.get_data_length() == 0 || tx.get_data_length() > 8
      || (tx.get_address() & (tx.get_data_length() - 1)) != 0) {
    tx.set_response_status(tlm::TLM_BURST_ERROR_RESPONSE);
    return;
  }

  const auto index = ((tx.get_address() - base_[target]) >> 3) % memory_[target].size();
  std::uint64_t word = memory_[target][index];
  if (tx.is_write()) {
    const unsigned char* enables = tx.get_byte_enable_ptr();
    for (unsigned byte = 0; byte < tx.get_data_length(); ++byte) {
      if (!enables || enables[byte % tx.get_byte_enable_length()] != 0) {
        const std::uint64_t mask = 0xffULL << (byte * 8);
        word = (word & ~mask) | (std::uint64_t(tx.get_data_ptr()[byte]) << (byte * 8));
      }
    }
    memory_[target][index] = word;
  } else {
    std::memcpy(tx.get_data_ptr(), &word, tx.get_data_length());
  }
  delay += sc_core::sc_time(10 + attr->qos, sc_core::SC_NS);
  tx.set_response_status(tlm::TLM_OK_RESPONSE);
}
