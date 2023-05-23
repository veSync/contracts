import { task } from "hardhat/config";

const VOTER_ADDRESS = "0xca9c5032D9C72A5028cC760Fd0Cbb45798e68705"; // mainnet

async function deploy(taskArgs: any) {
  const hre = require("hardhat");

  const c = await hre.ethers.getContractAt("Voter", VOTER_ADDRESS);
  const numGauges = await c.length();
  console.log(`numGauges: ${numGauges}`);

  for (let i = 0; i < numGauges; i++) {
    const pool = await c.pools(i);
    console.log(`id: ${i}, pool: ${pool}`);
    const gauge = await c.gauges(pool);
    const isAlive = await c.isAlive(gauge);
    if (!isAlive) {
      console.log(`id: ${i}, pool: ${pool}, gauge: ${gauge}, is not alive. Skipping...`);
      continue;
    }
    console.log("sending tx...")
    try {
      await c['distribute(uint256,uint256)'](i, i + 1);
    }
    catch (e) {
      console.log(`id: ${i}, pool: ${pool}, gauge: ${gauge}, error: ${e}`);
    }
    console.log("tx sent");
  }
}
// deploy
task("deploy:distribute", "Voter.distribute - should be called every epoch")
  .setAction(deploy);
