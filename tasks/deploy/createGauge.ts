import { task } from "hardhat/config";

const VOTER_ADDRESS = "0xB90188506aC8E3cC8f59C968232f041BDd58BD81"; // testnet

async function deploy(taskArgs: any) {
  const hre = require("hardhat");

  const voter = await hre.ethers.getContractAt("Voter", VOTER_ADDRESS);
  
  await voter.createGauge(taskArgs.pairAddress);

}
// deploy
task("deploy:createGauge", "Create gauge for a pair")
  .addPositionalParam("pairAddress")
  .setAction(deploy);
