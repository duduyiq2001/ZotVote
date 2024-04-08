import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("master", (m) => {
  const master = m.contract("MasterOrg", []);

  return { master };
});
