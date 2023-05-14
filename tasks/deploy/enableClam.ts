import { task } from "hardhat/config";

import EnableClaimConfig from "./constants/zkEnableClaimConfig";
import testEnableClaimConfig from "./constants/zkTestEnableClaimConfig";
async function deploy(taskArgs: any) {
  let useConfig;
  // only when set network param to online, it will be online
  if (taskArgs.targetNetwork == "online") {
    useConfig = EnableClaimConfig;
  } else {
    useConfig = testEnableClaimConfig;
  }

  console.log(useConfig);

  const hre = require("hardhat");

  console.log(`Running deploy script for the ve contracts`);

  var tokenSaleAddress = useConfig.tokenSaleAddress;

  const vs = await hre.ethers.getContractAt("VS", useConfig.vsAddress);
  const tokenSale = await hre.ethers.getContractAt(
    "TokenSale",
    useConfig.tokenSaleAddress
  );

  await vs.approve(tokenSaleAddress, useConfig.tokenAndBonusToSaleAmount);
  await tokenSale.setSaleTokenAndVe(
    useConfig.vsAddress,
    useConfig.votingEscrowAddress
  );
  await tokenSale.enableClaim();

  console.log(
    "network:",
    taskArgs.targetNetwork,
    "TokenSale contracts enable claim"
  );
}
// deploy
task("deploy:enableClaim", "Enable TokeSale claim")
  .addPositionalParam("targetNetwork")
  .setAction(deploy);
