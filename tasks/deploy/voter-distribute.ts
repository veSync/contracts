import { task } from "hardhat/config";

const VOTER_ADDRESS = "0xBaC881E32825109CD18Bc5D54befbb2E067Db809"; // testnet

async function deploy(taskArgs: any) {
  const hre = require("hardhat");

  const c = await hre.ethers.getContractAt("Voter", VOTER_ADDRESS);
  await c['distribute()']()

}
// deploy
task("deploy:distribute", "Voter.distribute - should be called every epoch")
  .setAction(deploy);
