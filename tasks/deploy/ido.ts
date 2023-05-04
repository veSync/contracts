import { task } from "hardhat/config";
import * as ethers from "ethers";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";
import { Wallet } from "zksync-web3";

import IDOConfig from "./constants/zkIDOConfig";
import testIDOConfig from "./constants/zkTestIDOConfig";

import { ZkSyncArtifact } from "@matterlabs/hardhat-zksync-deploy/dist/types";

async function deploy(taskArgs: any) {
  let useConfig;
  // only when set network param to online, it will be online
  if (taskArgs.targetNetwork == "online") {
    useConfig = IDOConfig;
  } else {
    useConfig = testIDOConfig;
  }
  console.log("useConfig:", useConfig);

  const hre = require("hardhat");

  console.log(`Running deploy script for the ve contracts`);

  const wallet = new Wallet(useConfig.deployPK ?? "");
  const deployer = new Deployer(hre, wallet);

  // Load
  const [TokenSale] = await Promise.all([deployer.loadArtifact("TokenSale")]);

  async function deployContract(
    contract: ZkSyncArtifact,
    parameters: any[] = []
  ) {
    let deploymentFee = await deployer.estimateDeployFee(contract, parameters);
    console.log("deployer.zkWallet.address: ", deployer.zkWallet.address);
    const parsedFee = ethers.utils.formatEther(deploymentFee.toString());
    console.log(`The deployment is estimated to cost ${parsedFee} ETH`);

    const contractObj = await deployer.deploy(contract, parameters);
    console.log(
      "constructor args:" + contractObj.interface.encodeDeploy(parameters)
    );
    const contractAddress = contractObj.address;
    console.log(`${contract.contractName} was deployed to ${contractAddress}`);
    return contractObj;
  }

  var tokenSale = await deployContract(TokenSale, [
    useConfig.conversionRate,
    ethers.BigNumber.from(useConfig.tokenToSaleAmount),
    useConfig.BonusEndTimestamp,
  ]);
  await tokenSale.setMerkleRoot(useConfig.merkleRoot);

  console.log(
    "network:",
    taskArgs.targetNetwork,
    "TokenSale contracts deployed"
  );
}
// deploy
task("deploy:ido", "Deployed TokeSale contracts")
  .addPositionalParam("targetNetwork")
  .setAction(deploy);
