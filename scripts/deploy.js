const hre = require("hardhat");

const host = '0xEB796bdb90fFA0f28255275e16936D25d3418603';
const cfa = '0x49e565Ed1bdc17F3d220f72DF0857C26FA83F873';
const fDAIx = '0x5D8B4C2554aeB7e86F387B4d6c00Ac33499Ed01f';

//your address here...
const receiver = '0x41A10AFC05B4c18eF384c1cA88E5AC6c116cF7bE';

const main = async () => {
  console.log('here');
  const SuperAppPOC = await hre.ethers.getContractFactory("SuperAppPOC");
  console.log(SuperAppPOC);
  const superAppPOC = await SuperAppPOC.deploy(host, fDAIx, receiver);
  console.log(superAppPOC);
  await superAppPOC.deployed();

  console.log("SuperAppPOC deployed to:", superAppPOC.address);
}

const runMain = async () => {
  try {
    await main();
    process.exit(0);
  } catch (error) {
    console.log('Error deploying contract', error);
    process.exit(1);
  }
}

runMain();
