const testIDOConfig = {
  
  merkleRoot: "0x2c62e4b12c162266ae9ac1e53c1eb8ee6e0a82a66264733d3b57ee394c27e182",

  tokenToSaleAmount: "500000000000000000000000",
  
  // 1 ETH = 0.000000035 Token
  conversionRate: 28571428571,

  BonusEndTimestamp: 1683221400,

  deployPK: process.env.ZK_TEST_DEPLOY_PRIVATE_KEY
};

export default testIDOConfig;
