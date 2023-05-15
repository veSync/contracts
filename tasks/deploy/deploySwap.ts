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
    const [
        Router,
        Library,
      ] = await Promise.all([
        deployer.loadArtifact("Router"),
        deployer.loadArtifact("VelodromeLibrary"),
      ]);

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

  const pairFactory = {address: "0xf608F094D95a8030A722bBd8DF75dFeD2cc08585"};
  const WETH = {address: "0x20b28B1e4665FFf290650586ad76E977EAb90c5D"};

  var router = await deployContract(Router, [pairFactory.address, WETH.address]);
  var library = await deployContract(Library, [router.address]);

}
task("deploy:swap", "Deployed swap contracts")
  .addPositionalParam("targetNetwork")
  .setAction(deploy);
