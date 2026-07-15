#pragma once

#include <array>
#include <cstdint>
#include <systemc>
#include <tlm>
#include <tlm_utils/simple_target_socket.h>

struct FabricAttributes : tlm::tlm_extension<FabricAttributes> {
  unsigned master = 0;
  unsigned id = 0;
  unsigned qos = 0;
  bool secure = true;

  tlm_extension_base* clone() const override { return new FabricAttributes(*this); }
  void copy_from(const tlm_extension_base& other) override {
    *this = static_cast<const FabricAttributes&>(other);
  }
};

class FabricTlmModel : public sc_core::sc_module {
 public:
  tlm_utils::simple_target_socket<FabricTlmModel> socket;

  SC_HAS_PROCESS(FabricTlmModel);
  explicit FabricTlmModel(sc_core::sc_module_name name);

  void b_transport(tlm::tlm_generic_payload& tx, sc_core::sc_time& delay);
  int decode(std::uint64_t address) const;
  unsigned choose(const std::array<bool, 4>& request,
                  const std::array<unsigned, 4>& qos,
                  const std::array<unsigned, 4>& age,
                  unsigned rr_pointer) const;

 private:
  std::array<std::uint32_t, 4> base_{{0x00000000, 0x10000000, 0x20000000, 0x30000000}};
  std::array<std::uint32_t, 4> mask_{{0xffff0000, 0xffff0000, 0xffff0000, 0xffff0000}};
  std::array<bool, 4> secure_only_{{false, false, true, false}};
  std::array<std::array<bool, 4>, 4> allow_{};
  std::array<std::array<std::uint64_t, 8192>, 4> memory_{};
};
