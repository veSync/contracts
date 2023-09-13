import { task } from "hardhat/config";

// usage 
// npx hardhat deploy:distribute --network zkMain

const VOTER_ADDRESS = "0xca9c5032D9C72A5028cC760Fd0Cbb45798e68705"; // mainnet
const VS_ADDRESS = "0x5756A28E2aAe01F600FC2C01358395F5C1f8ad3A";

async function deploy(taskArgs: any) {
  const hre = require("hardhat");

  const c = await hre.ethers.getContractAt("Voter", VOTER_ADDRESS);

  const i = 7;

  console.log("sending tx...")
  try {
    await c['distribute(uint256,uint256)'](i, i + 1, { gasLimit: 1000000 });
  }
  catch (e) {
    console.log(`id: ${i}, error: ${e}`);
  }
  console.log("tx sent");

}
// deploy
task("deploy:distributedebug", "Voter.distribute - should be called every epoch")
  .setAction(deploy);
