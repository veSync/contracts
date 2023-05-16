import { Command } from 'commander'
import { BigNumber, ethers } from "ethers"
import * as fs from 'fs'
import { StandardMerkleTree } from "@openzeppelin/merkle-tree";

const program = new Command();
program
  .version('0.0.0')
  .requiredOption(
    '-i, --input <path>',
    'input JSON file location containing a map of account addresses to string balances'
  )

program.parse(process.argv)

const options = program.opts()
const json = JSON.parse(fs.readFileSync(options.input, { encoding: 'utf8' }))

if (typeof json !== 'object') throw new Error('Invalid JSON')

const values: any[] = [];
let totalAmount = 0;
for (const key in json) {
  const amountWithPrivateSaleBonus = BigNumber.from(json[key]).mul(125).div(100); // 1.25x
  totalAmount += Number(ethers.utils.formatEther(amountWithPrivateSaleBonus.toString()));
  values.push([key, amountWithPrivateSaleBonus.toString()]);
}

const tree = StandardMerkleTree.of(values, ["address", "uint256"]);

const result: any = {
  root: tree.root,
};

for (const [i, v] of tree.entries()) {
  const proof = tree.getProof(i);
  result[v[0]] = {
    index: i,
    amount: v[1],
    proof: proof,
    decimalAmount: ethers.utils.formatEther(v[1]),
  }
}

fs.writeFileSync("private_sale_proof.json", JSON.stringify(result));

console.log("total amount: ", totalAmount, "VS")
console.log("total amount as input param to private sale contract:", ethers.utils.parseEther(totalAmount.toString()).toBigInt());
console.log("total amount plus 30% bonus: ", totalAmount * 1.3, "VS")