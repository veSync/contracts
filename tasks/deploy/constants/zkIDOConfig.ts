const IDOConfig = {
  merkleRoot:
    "0x5eaff386f5bfeac293970a4d02ff1422e2e084a621f933dcb5294252f8e00d16",

  tokenToSaleAmount: "5314285714206000000000000",

  // 1 ETH = 0.000000035 Token
  conversionRate: 28571428571,

  // UTC: Thursday, May 18, 2023 12:00:00 AM
  BonusEndTimestamp: 1684368000,

  deployPK: process.env.ZK_DEPLOY_PRIVATE_KEY,
};

export default IDOConfig;
