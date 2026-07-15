#include "fabric_tlm_model.h"

#include <array>
#include <cstdint>
#include <iostream>
#include <tlm_utils/simple_initiator_socket.h>

class Initiator : public sc_core::sc_module {
 public:
  tlm_utils::simple_initiator_socket<Initiator> socket;
  explicit Initiator(sc_core::sc_module_name name) : sc_core::sc_module(name), socket("socket") {}

  tlm::tlm_response_status access(bool write, std::uint64_t address, std::uint64_t& data,
                                  unsigned master, unsigned qos, bool secure) {
    tlm::tlm_generic_payload tx;
    FabricAttributes attr;
    attr.master = master;
    attr.id = master + 1;
    attr.qos = qos;
    attr.secure = secure;
    tx.set_extension(&attr);
    tx.set_command(write ? tlm::TLM_WRITE_COMMAND : tlm::TLM_READ_COMMAND);
    tx.set_address(address);
    tx.set_data_ptr(reinterpret_cast<unsigned char*>(&data));
    tx.set_data_length(sizeof(data));
    tx.set_streaming_width(sizeof(data));
    sc_core::sc_time delay = sc_core::SC_ZERO_TIME;
    socket->b_transport(tx, delay);
    tx.clear_extension(&attr);
    return tx.get_response_status();
  }
};

int sc_main(int, char**) {
  FabricTlmModel model("model");
  Initiator initiator("initiator");
  initiator.socket.bind(model.socket);
  unsigned checks = 0;
  unsigned errors = 0;
  auto check = [&](bool condition, const char* name) {
    ++checks;
    if (!condition) { ++errors; std::cerr << "CHECK_FAIL|" << name << '\n'; }
  };

  std::uint64_t data = 0x1122334455667788ULL;
  check(initiator.access(true, 0x00000040, data, 0, 0, true) == tlm::TLM_OK_RESPONSE,
        "mapped write");
  data = 0;
  check(initiator.access(false, 0x00000040, data, 0, 0, true) == tlm::TLM_OK_RESPONSE,
        "mapped read");
  check(data == 0x1122334455667788ULL, "readback");
  check(initiator.access(false, 0xF0000000, data, 0, 0, true)
        == tlm::TLM_ADDRESS_ERROR_RESPONSE, "decode error");
  check(initiator.access(false, 0x20000000, data, 1, 0, false)
        == tlm::TLM_ADDRESS_ERROR_RESPONSE, "security denial");

  std::array<bool, 4> request{{true, true, false, false}};
  std::array<unsigned, 4> qos{{1, 15, 0, 0}};
  std::array<unsigned, 4> age{{0, 0, 0, 0}};
  check(model.choose(request, qos, age, 0) == 1, "qos winner");
  age[0] = 31;
  check(model.choose(request, qos, age, 0) == 0, "age override");

  std::cout << "MODEL_RESULT|checks=" << checks << "|errors=" << errors << '\n';
  return errors ? 1 : 0;
}
