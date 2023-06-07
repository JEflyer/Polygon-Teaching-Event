const ethers = require("ethers")
const Table = require("cli-table")
const { abi: minterABI, bytecode: minterBytecode } = require("../artifacts/contracts/Minter.sol/Minter.json")
const { abi: stakingABI, bytecode: stakingBytecode } = require("../artifacts/contracts/Staking.sol/Staking.json")
const { abi: tokenABI, bytecode: tokenBytecode } = require("../artifacts/contracts/Token.sol/Token.json")


const privateKeyDeployer = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
const privateKeyUser1 = "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
const privateKeyUser2 = "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a"

const RPC = "http://127.0.0.1:8545/"

const provider = new ethers.providers.JsonRpcProvider(RPC)

const deployer = new ethers.Wallet(privateKeyDeployer, provider)
const user1 = new ethers.Wallet(privateKeyUser1, provider)
const user2 = new ethers.Wallet(privateKeyUser2, provider)

const minterFactory = new ethers.ContractFactory(minterABI, minterBytecode, deployer)
const tokenFactory = new ethers.ContractFactory(tokenABI, tokenBytecode, deployer)
const stakingFactory = new ethers.ContractFactory(stakingABI, stakingBytecode, deployer)

const initialTreasury = ethers.utils.parseEther("1000")

const payees = [
    "0xBcd4042DE499D14e55001CcbB24a551F3b954096",
    "0xa0Ee7A142d267C1f36714E4a8F75612F20a79720",
    "0xbDA5747bFD65F08deb54cb465eB87D40e51B197E",
    "0xdD2FD4581271e230360230F9337D5c0430Bf44C0",
    "0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199"
]
const amounts = [
    100,
    250,
    330,
    101,
    232
]

const mintFee = ethers.utils.parseEther("2")
const mintLimit = 1000
const baseURI = "https://ipfs.io/ipfs/<CID>/"

function log(message) {
    console.log(message)
}

function sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
}

async function start() {
    log("Deploying minter")
    let minter = await minterFactory.deploy(payees, amounts, mintFee, mintLimit, baseURI)
    await minter.deployed()
    log(`Minter deployed @ ${minter.address}`)


    log("Deploying token")
    let token = await tokenFactory.deploy()
    await token.deployed()
    log(`Token deployed @ ${token.address}`)


    log("Deploying minter")
    let staking = await stakingFactory.deploy(initialTreasury, token.address, minter.address)
    await staking.deployed()
    log(`Staking contract deployed @ ${staking.address}`)

    log("Initializing the token")
    let tx = await token.initialize(staking.address)
    await tx.wait()
    log("Token initialized")

    log("Getting balances")
    let ownerBal = await token.balanceOf(deployer.address)
    let user1Bal = await token.balanceOf(user1.address)
        // log(`Owner Balance: ${ethers.utils.formatEther(ownerBal)}`)
        // log(`User1 Balance: ${ethers.utils.formatEther(user1Bal)}`)

    log("Getting totalSupply")
    let supply = await token.totalSupply()
        // log(`Total Supply: ${ethers.utils.formatEther(supply)}`)

    const table = new Table({
        head: ['Owner Balance', 'User1 Balance', 'TotalSupply'],
    });
    table.push(
        [ethers.utils.formatEther(ownerBal), ethers.utils.formatEther(user1Bal), ethers.utils.formatEther(supply)]
    );
    log(table.toString())

    log("Trasferring 100 tokens from the deployer wallet to user1's wallet")
    let tx2 = await token.transfer(user1.address, ethers.utils.parseEther("100"))
    await tx2.wait()
    log("Tokens transferred successfully")

    log("Getting balances")
    let ownerBal2 = await token.balanceOf(deployer.address)
    let user1Bal2 = await token.balanceOf(user1.address)
        // log(`Owner Balance: ${ethers.utils.formatEther(ownerBal2)}`)
        // log(`User1 Balance: ${ethers.utils.formatEther(user1Bal2)}`)


    log("Getting totalSupply")
    let supply2 = await token.totalSupply()
        // log(`Total Supply: ${ethers.utils.formatEther(supply2)}`)

    const table2 = new Table({
        head: ['Owner Balance', 'User1 Balance', 'TotalSupply'],
    });
    table2.push(
        [ethers.utils.formatEther(ownerBal2), ethers.utils.formatEther(user1Bal2), ethers.utils.formatEther(supply2)]
    );
    log(table2.toString())

    log("User 1 is minting a NFT")
    let tx3 = await (new ethers.Contract(minter.address, minterABI, user1)).Mint({ value: mintFee })
    await tx3.wait()
    log("User 1 has minted a NFT")

    log("User 2 is minting a NFT")
    let tx4 = await (new ethers.Contract(minter.address, minterABI, user2)).Mint({ value: mintFee })
    await tx4.wait()
    log("User 2 has minted a NFT")

    log("User 1 & User 2 are approving the staking contract to spend their NFTs")
    let approvalTx1 = await (new ethers.Contract(minter.address, minterABI, user1)).approve(staking.address, 1)
    await approvalTx1.wait()
    let approvalTx2 = await (new ethers.Contract(minter.address, minterABI, user2)).approve(staking.address, 2)
    await approvalTx2.wait()
    log("Approved")

    // log("Getting NFTs that User 1 owns")
    // let bal = await minter.walletOfOwner(user1.address)
    // console.log(bal)

    log("User 1 is staking their NFT")
    let tx5 = await (new ethers.Contract(staking.address, stakingABI, user1)).stake(1)
    log("User 2 is staking their NFT")
    let tx6 = await (new ethers.Contract(staking.address, stakingABI, user2)).stake(2)
    await tx5.wait()
    await tx6.wait()
    log("The NFTs have been staked")

    log("Sleeping for 100 seconds")
    await sleep(100000)

    log("Unstaking User 1's NFT")
    let tx7 = await (new ethers.Contract(staking.address, stakingABI, user1)).unstake(1)
    await tx7.wait()
    log("Unstaked")

    log("Sleeping for 100 seconds")
    await sleep(100000)

    log("Unstaking User 2's NFT")
    let tx8 = await (new ethers.Contract(staking.address, stakingABI, user2)).unstake(2)
    await tx8.wait()
    log("Unstaked")

    log("Getting balances")
    let user1Bal3 = await token.balanceOf(user1.address)
    let user2Bal3 = await token.balanceOf(user2.address)
        // log(`User1 Balance: ${ethers.utils.formatEther(user1Bal3)}`)
        // log(`User2 Balance: ${ethers.utils.formatEther(user2Bal3)}`)

    log("Getting totalSupply")
    let supply3 = await token.totalSupply()

    const table3 = new Table({
        head: ['User1 Balance', 'User2 Balance', 'TotalSupply'],
    });
    table3.push(
        [ethers.utils.formatEther(user1Bal3), ethers.utils.formatEther(user2Bal3), ethers.utils.formatEther(supply3)]
    );
    log(table3.toString())

}

start()