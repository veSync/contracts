import { task } from "hardhat/config";

// usage 
// npx hardhat deploy:distribute --network zkMain

const VOTER_ADDRESS = "0xca9c5032D9C72A5028cC760Fd0Cbb45798e68705"; // mainnet
const VS_ADDRESS = "0x5756A28E2aAe01F600FC2C01358395F5C1f8ad3A";

// skip major gauges
const SKIP_GAUGE = ["0xd6753a142C9fd1ac6281D738BaD0e2cFf9C91c4B", "0x3af4678f3dcE1051EF182f222979D25920C6e342", "0x0a35447c43D766BDa5C41d32AF2376ECA8BDaDa5"].map(x => x.toLowerCase());

async function deploy(taskArgs: any) {
  const hre = require("hardhat");

  const c = await hre.ethers.getContractAt("Voter", VOTER_ADDRESS);
  const numGauges = await c.length();
  console.log(`numGauges: ${numGauges}`);

  for (let i = 0; i < numGauges; i++) {
    const pool = await c.pools(i);
    console.log(`id: ${i}, pool: ${pool}`);
    const gauge = await c.gauges(pool);
    // if (SKIP_GAUGE.includes(gauge.toLowerCase())) {
    //   console.log(`id: ${i}, pool: ${pool}, gauge: ${gauge}, is skipped. Skipping...`);
    //   continue;
    // }
    const isAlive = await c.isAlive(gauge);
    if (!isAlive) {
      console.log(`id: ${i}, pool: ${pool}, gauge: ${gauge}, is not alive. Skipping...`);
      continue;
    }

    const gaugeContract = await hre.ethers.getContractAt("Gauge", gauge);
    const periodFinish = await gaugeContract.periodFinish(VS_ADDRESS);
    if (periodFinish > Date.now() / 1000) {
      console.log(`id: ${i}, pool: ${pool}, gauge: ${gauge}, remaining days: ${(periodFinish - Date.now() / 1000) / 86400}, is not finished. Skipping...`);
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
