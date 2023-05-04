const IDOConfig = {
  
  merkleRoot: "",

  tokenToSaleAmount: "",

  // 1 ETH = 0.000000035 Token
  conversionRate: 28571428571,

  // UTC: Thursday, May 18, 2023 12:00:00 AM
  BonusEndTimestamp: 1684368000,

  deployPK: process.env.ZK_DEPLOY_PRIVATE_KEY
};

export default IDOConfig;
