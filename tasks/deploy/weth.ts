import { task } from "hardhat/config";
import * as ethers from "ethers";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";
import { Wallet } from "zksync-web3";

import { ZkSyncArtifact } from "@matterlabs/hardhat-zksync-deploy/dist/types";
import { assert } from "console";

async function deploy(taskArgs: any) {
  // only deploy WETH in testnet
  assert(taskArgs.targetNetwork == "test");

  const hre = require("hardhat");

  const wallet = new Wallet(process.env.ZK_TEST_DEPLOY_PRIVATE_KEY as string);
  const deployer = new Deployer(hre, wallet);

  // Below is for deploying WETH
  
  //const [WETH] = await Promise.all([deployer.loadArtifact("WETH9")]);

  // async function deployContract(
  //   contract: ZkSyncArtifact,
  //   parameters: any[] = []
  // ) {
  //   let deploymentFee = await deployer.estimateDeployFee(contract, parameters);
  //   console.log("deployer.zkWallet.address: ", deployer.zkWallet.address);
  //   const parsedFee = ethers.utils.formatEther(deploymentFee.toString());
  //   console.log(`The deployment is estimated to cost ${parsedFee} ETH`);

  //   const contractObj = await deployer.deploy(contract, parameters, { gasLimit: 130979516});
  //   console.log(
  //     "constructor args:" + contractObj.interface.encodeDeploy(parameters)
  //   );
  //   const contractAddress = contractObj.address;
  //   console.log(`${contract.contractName} was deployed to ${contractAddress}`);
  //   return contractObj;
  // }
  
  // let deployed = await deployContract(WETH, []);
  
  const weth = await hre.ethers.getContractAt("WETH9", "0xACf3D7D7Fe5Ae8B16C73cBd59a21Ab6C573Ef5cD");

  await weth.deposit({value: ethers.utils.parseEther("0.1")});
}
// deploy
task("deploy:weth", "Deploy Testnet WETH contract")
  .addPositionalParam("targetNetwork")
  .setAction(deploy);
