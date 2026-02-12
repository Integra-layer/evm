const { ethers } = require('ethers');

async function main() {
    // Treasury wallet (you'll need to provide the private key)
    const TREASURY_ADDRESS = '0xb5e1a3aeca9756e7c9771aec90a77e962d2835f4';
    const TEST_WALLET = '0xeDD61a49598B1f063e0BB9510b11D3a50a36f83C';
    
    const provider = new ethers.JsonRpcProvider('https://evm.integralayer.com');
    
    console.log('\n📊 Current Balances:');
    const treasuryBal = await provider.getBalance(TREASURY_ADDRESS);
    const testBal = await provider.getBalance(TEST_WALLET);
    console.log(`Treasury: ${ethers.formatEther(treasuryBal)} IRL`);
    console.log(`Test Wallet: ${ethers.formatEther(testBal)} IRL`);
    
    console.log('\n⚠️  To fund the test wallet, you need the treasury private key.');
    console.log('Run this command with the treasury key:\n');
    console.log(`node fund-test-wallet.js <TREASURY_PRIVATE_KEY>\n`);
}

if (process.argv[2]) {
    const { ethers } = require('ethers');
    const provider = new ethers.JsonRpcProvider('https://evm.integralayer.com');
    const treasury = new ethers.Wallet(process.argv[2], provider);
    const TEST_WALLET = '0xeDD61a49598B1f063e0BB9510b11D3a50a36f83C';
    
    (async () => {
        console.log('\n💸 Sending 1000 IRL to test wallet...');
        const tx = await treasury.sendTransaction({
            to: TEST_WALLET,
            value: ethers.parseEther('1000'),
            gasLimit: 21000
        });
        console.log(`✅ Transaction sent: ${tx.hash}`);
        console.log('Waiting for confirmation...');
        await tx.wait();
        console.log('✅ Confirmed!\n');
        
        const newBal = await provider.getBalance(TEST_WALLET);
        console.log(`New balance: ${ethers.formatEther(newBal)} IRL\n`);
    })();
} else {
    main().catch(console.error);
}
