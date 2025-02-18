const zkMinterConfig = {
    TeamAddress: "0x049945a3CA940310e0dB3517662C084eA22e5d8e",
    MarketingAddress: "0xCA0e61199E525277857Ca69B1c3F33A9EE688C74",
    EcosystemAddress: "0x7Ed838AD3050D580465DA8593B86392C214dC74C",
    AirdropAddress: "0x4517F52f98dEE7Dad3B0498635295D7Ab8891312",
    LiquidityAddress: "0x7abb50C0e1150A794CAB812F14C9C348A1796541",
    IDOAddress: "0x8940d378057582A0468DbDA115cCBF26342ccfa5",
    TeamLockAmount:  "14000000000000000000000000",//14M
    IDOAmount:       "10000000000000000000000000",//10M
    AirdropAmount:   "40000000000000000000000000",//18M + 22M = 40M
    EcosystemAmount: "20000000000000000000000000",//20M
    LiquidityAmount:  "5000000000000000000000000",//5M
    MarketingAmount: "11000000000000000000000000",//7M + 4M = 11M
    deployPK: process.env.ZK_DEPLOY_PRIVATE_KEY,
  };
  
  export default zkMinterConfig;
  