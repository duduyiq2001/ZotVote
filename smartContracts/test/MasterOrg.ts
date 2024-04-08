import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("MasterOrg", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployMaster() {
    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount, otherAccount2] = await ethers.getSigners();

    const MasterOrg = await ethers.getContractFactory("MasterOrg");
    const master = await MasterOrg.deploy();
    //     (property) MasterOrg.addOrg: TypedContractMethod
    // (...args: ContractMethodArgs<[orgName: string, settings: OrgSettingsStruct, newOrgOwner: AddressLike], "nonpayable">) => Promise<ContractTransactionResponse>
    const Orgsettings = { majority: 50, qourum: 80 };

    return { master, owner, otherAccount, otherAccount2, Orgsettings };
  }
  describe("Deployment", function () {
    it("owner should be the one who deployed ", async function () {
      const { master, owner, otherAccount } = await loadFixture(deployMaster);
      expect(await master.owner()).to.equal(owner.address);
    });
  });

  describe("Orgs modding", function () {
    it("should be able to add a org", async function () {
      const { master, owner, otherAccount, otherAccount2, Orgsettings } =
        await loadFixture(deployMaster);
      // creating a org
      const response = await master.addOrg(
        "blockchainuci",
        Orgsettings,
        otherAccount
      );
      const newAddr = response.data.at(0)?.split(" ")[1];
      // the new address or org is not null
      expect(newAddr != null);
      if (newAddr != null) {
        //the new address is valid
        expect(ethers.isAddress(newAddr)).to.equal(true);
        // the new address exists in mapping
        expect(await master.orgAddresses(newAddr)).to.equal(1);
        // a random address shoudl not exist
        expect(await master.orgAddresses(newAddr)).to.equal(0);
      }
    });
    it("Should fail if nonowner create org", async function () {
      const { master, owner, otherAccount, otherAccount2, Orgsettings } =
        await loadFixture(deployMaster);
      // change user to otherAccount
      const master1 = await master.connect(otherAccount);

      await expect(master1.addOrg("blockchainuci", Orgsettings, otherAccount))
        .to.be.reverted;
    });
  });
});
