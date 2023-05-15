import { task } from "hardhat/config";
import * as ethers from "ethers";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";
import { Wallet, utils } from "zksync-web3";

import { Artifact } from 'hardhat/types';

// import zkConfig from "./constants/zkConfig";
import testZkConfig from "./constants/testZkConfig";

import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ZkSyncArtifact } from "@matterlabs/hardhat-zksync-deploy/dist/types";

// async function deploy(hre: HardhatRuntimeEnvironment) {
async function deploy() {
   const hre = require("hardhat")

    console.log(`Running deploy script for the ve contracts`);
    const wallet = new Wallet("039059c335c31d79928eab0f7fc21752851a44a854255d72f61763c370885588");
    const deployer = new Deployer(hre, wallet);

    // Load
  const [
    Velo,
    GaugeFactory,
    BribeFactory,
    PairFactory,
    Router,
    Library,
    VeArtProxy,
    VotingEscrow,
    RewardsDistributor,
    Voter,
    Minter,
    TokenSale,
    // VeloGovernor
  ] = await Promise.all([
    deployer.loadArtifact("Velo"),
    deployer.loadArtifact("GaugeFactory"),
    deployer.loadArtifact("BribeFactory"),
    deployer.loadArtifact("PairFactory"),
    deployer.loadArtifact("Router"),
    deployer.loadArtifact("VelodromeLibrary"),
    deployer.loadArtifact("VeArtProxy"),
    deployer.loadArtifact("VotingEscrow"),
    deployer.loadArtifact("RewardsDistributor"),
    deployer.loadArtifact("Voter"),
    deployer.loadArtifact("Minter"),
    deployer.loadArtifact("TokenSale"),
    // deployer.loadArtifact("VeloGovernor"),
  ]);

  async function deployContract(contract: ZkSyncArtifact, parameters: any[] = []) {
    // let deploymentFee = await deployer.estimateDeployFee(contract, parameters);
    // console.log(`The deployment fee is ${deploymentFee} wei`);
    // console.log("deployer.zkWallet.address: ", deployer.zkWallet.address);


    // const depositHandle = await deployer.zkWallet.deposit({
    //   to: deployer.zkWallet.address,
    //   token: utils.ETH_ADDRESS,
    //   amount: deploymentFee.mul(2),
    // });

    // await depositHandle.wait();

    // const parsedFee = ethers.utils.formatEther(deploymentFee.toString());
    // console.log(`The deployment is estimated to cost ${parsedFee} ETH`);

    const contractObj = await deployer.deploy(contract, parameters);
    // console.log("constructor args:" + contractObj.interface.encodeDeploy(parameters));
    const contractAddress = contractObj.address;
    console.log(`${contract.contractName} was deployed to ${contractAddress}`);
    return contractObj;
  }

//   var bribeFactory = await deployContract(BribeFactory);
//   var pairFactory = await deployContract(PairFactory);
 
//   var gaugeFactory = await deployContract(GaugeFactory);
//   var router = await deployContract(Router, [pairFactory.address, testZkConfig.WETH]);
//   var library = await deployContract(Library, [router.address]);
  // var veArtProxy =  await deployContract(VeArtProxy, []);
  var pairFactory = {address: "0xf608F094D95a8030A722bBd8DF75dFeD2cc08585"};
  var gaugeFactory = {address: "0xC70aE762B49c479a81d1684D73F55eC9AAe2829d"};
  var bribeFactory = {address: "0x4f579a05d18F7667A06F272e99d9bD8FB723FAE9"};
  let veArtProxy = {address: "0x2380Eae342Cfd2a9B54F7364Bba073E04976C395"};

  var velo = await deployContract(Velo);
  var votingEscrow = await deployContract(VotingEscrow, [velo.address, veArtProxy.address]);
  var rewardsDistributor = await deployContract(RewardsDistributor, [votingEscrow.address]);

//   var voter = await deployContract(Voter, [votingEscrowAddress, pairFactoryAddress, gaugeFactory.address, bribeFactory.address]);
  // var voter = await deployContract(Voter, [votingEscrowAddress, pairFactoryAddress, gaugeFactoryAddress, bribeFactoryAddress]);
  var voter = await deployContract(Voter, [votingEscrow.address, pairFactory.address, gaugeFactory.address, bribeFactory.address]);
  var minter = await deployContract(Minter, [voter.address, votingEscrow.address, rewardsDistributor.address]);


  // var veloGovernor = await deployContract(VeloGovernor, [votingEscrow.address]);

  pairFactory = await hre.ethers.getContractAt("PairFactory", pairFactory.address);
//   votingEscrow = await hre.ethers.getContractAt("VotingEscrow", votingEscrow.address);
//   minter = await hre.ethers.getContractAt("Minter", minter.address);
//   voter = await hre.ethers.getContractAt("Voter", voter.address);
//   const rewardsDistributor = await hre.ethers.getContractAt("RewardsDistributor", rewardsDistributor.address);


  await velo.initialMint(testZkConfig.teamEOA);
  console.log("Initial minted");

  await velo.setMinter(minter.address);
  console.log("Minter set");
 
//   await pairFactory.setPauser(testZkConfig.teamMultisig);
//   console.log("Pauser set");
 
  await votingEscrow.setVoter(voter.address);
  console.log("Voter set");

  await votingEscrow.setTeam(testZkConfig.teamMultisig);
  console.log("Team set for escrow");

  await voter.setGovernor(testZkConfig.teamMultisig);
  console.log("Governor set");




  await voter.setEmergencyCouncil(testZkConfig.teamMultisig);
  console.log("Emergency Council set");

  await rewardsDistributor.setDepositor(minter.address);
  console.log("Depositor set");

  const nativeToken = [velo.address];
  const tokenWhitelist = nativeToken.concat(testZkConfig.tokenWhitelist);
  await voter.initialize(tokenWhitelist, minter.address);
  console.log("Whitelist set");

  // Initial veVELO distro
  await minter.initialize(
    testZkConfig.partnerAddrs,
    testZkConfig.partnerAmts,
    testZkConfig.partnerMax
  );
  console.log("veVELO distributed");

  await minter.setTeam(testZkConfig.teamMultisig)
  console.log("Team set for minter");


  console.log("ZK contracts deployed");

}
// deploy
task("deploy:app", "Deploys Zk sync contracts").setAction(deploy);