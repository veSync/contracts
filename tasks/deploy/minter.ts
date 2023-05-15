import { task } from "hardhat/config";
import * as ethers from "ethers";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";
import { Wallet } from "zksync-web3";

import onlineConfig from "./constants/generalOnlineConfig";
import testConfig from "./constants/generalTestConfig";

import { ZkSyncArtifact } from "@matterlabs/hardhat-zksync-deploy/dist/types";

async function deploy(taskArgs: any) {
  let useConfig;
  // only when set network param to online, it will be online
  if (taskArgs.targetNetwork == "online") {
    useConfig = onlineConfig;
  } else {
    useConfig = testConfig;
  }
  console.log("useConfig:", useConfig);

  const hre = require("hardhat");

  console.log(`Running deploy script for the ve contracts`);

  const wallet = new Wallet(useConfig.deployPK ?? "");
  const deployer = new Deployer(hre, wallet);

  // Load
  const [TimelockController] = await Promise.all([deployer.loadArtifact("TimelockController")]);

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

  let minDelay, proposerAddress_list, executor_list, admin;
  if (taskArgs.targetNetwork == "online") {
    throw new Error("not supported online network yet");
  } else {
    minDelay = 300; //5min
    proposerAddress_list = ["0x39EA6eF48c606b53a1efaea91aEbDF30d7a47837", "0xE1fD2490ACcf96e389BAd8327D743B26b2F68D2D", "0xc94527FdE2d01dd166991231120dCC2A6F09c303"];
    executor_list = ["0x39EA6eF48c606b53a1efaea91aEbDF30d7a47837", "0xE1fD2490ACcf96e389BAd8327D743B26b2F68D2D", "0xc94527FdE2d01dd166991231120dCC2A6F09c303"];
    admin = "0x39EA6eF48c606b53a1efaea91aEbDF30d7a47837"
  }

    await deployContract(TimelockController, [minDelay, proposerAddress_list, executor_list, admin]);

}
task("deploy:minter", "Deployed contracts")
  .addPositionalParam("targetNetwork")
  .setAction(deploy);
