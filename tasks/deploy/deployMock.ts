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
  const [WETH, MockERC20] = await Promise.all([deployer.loadArtifact("WETH9"), deployer.loadArtifact("MockERC20")]);

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

//   await deployContract(WETH, []);
    await deployContract(MockERC20, ['Mock Token1', 'Mock1']);
    await deployContract(MockERC20, ['Mock Token2', 'Mock2']);
    await deployContract(MockERC20, ['Mock Token3', 'Mock3']);
    await deployContract(MockERC20, ['Mock Token4', 'Mock4']);

}
task("deploy:mock", "Deployed mock contracts")
  .addPositionalParam("targetNetwork")
  .setAction(deploy);
