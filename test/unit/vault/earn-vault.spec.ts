import { expect } from 'chai';
import { ethers } from 'hardhat';
import { Contract, utils } from 'ethers';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
describe('EarnVault', () => {
    
    let vault: Contract;
    let strategy: Contract;
    let erc20: Contract;
    let strategyId: Number;
    let owner: SignerWithAddress;
    let anotherWallet: SignerWithAddress;
    let terms = "These are the terms & conditions";
    let amountToDeposit = 50000;
  
    before('Setup accounts and contracts', async () => {

        const erc20Factory = await ethers.getContractFactory('ERC20MintableBurnableMock');
        erc20 = await erc20Factory.deploy();
        [owner, anotherWallet] = await ethers.getSigners();

        const strategyFactory = await ethers.getContractFactory('EarnStrategyStateBalanceWithSignatureMock');
        strategy = await strategyFactory.deploy([erc20.address], [1], utils.toUtf8Bytes(terms));
        
        const strategyRegistryFactory = await ethers.getContractFactory('EarnStrategyRegistry');
        const strategyRegistry = await strategyRegistryFactory.deploy();
        
        strategyId = await strategyRegistry.callStatic.registerStrategy(owner.address, strategy.address);
        await strategyRegistry.registerStrategy(owner.address, strategy.address);
        
        const vaultFactory = await ethers.getContractFactory('EarnVault');
        vault = await vaultFactory.deploy(strategyRegistry.address, owner.address, [owner.address], owner.address);
        
        erc20.mint(owner.address ,amountToDeposit);
        erc20.approve(vault.address ,amountToDeposit);
        
    });

    describe("createPosition", () => {
        it('validate good signature', async () => {
            expect(await vault.createPosition(strategyId, erc20.address, amountToDeposit, owner.address, [], owner.signMessage(terms) , utils.toUtf8Bytes("12345"))).to.be.ok;
        });

        it('revert with bad signature', async () => {
            await expect( vault.createPosition(strategyId, erc20.address, amountToDeposit, owner.address, [], owner.signMessage("BAD TERMS") , utils.toUtf8Bytes("12345"))).to.be.revertedWithCustomError(strategy ,"InvalidTermsAndConditions");
        });

        it('revert with bad sender', async () => {
            await expect( vault.createPosition(strategyId, erc20.address, amountToDeposit, owner.address, [], anotherWallet.signMessage(terms) , utils.toUtf8Bytes("12345"))).to.be.revertedWithCustomError(strategy ,"InvalidTermsAndConditions");
        });
      });

});