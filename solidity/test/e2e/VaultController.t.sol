// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {CommonE2EBase, IERC20} from '@test/e2e/Common.sol';

import {VaultController} from '@contracts/core/VaultController.sol';
import {IVaultController} from '@interfaces/core/IVaultController.sol';
import {IVault} from '@interfaces/core/IVault.sol';
import {IOracleRelay} from '@interfaces/periphery/IOracleRelay.sol';
import {IAMPHClaimer} from '@interfaces/core/IAMPHClaimer.sol';
import {IVaultDeployer} from '@interfaces/core/IVaultDeployer.sol';
import {ChainlinkStalePriceLib} from '@contracts/periphery/oracles/ChainlinkStalePriceLib.sol';
import "forge-std/console.sol";
import "forge-std/Test.sol";

contract E2EVaultController is CommonE2EBase {
  uint256 public borrowAmount = 500 ether;
  uint96 public bobsVaultId = 1;
  uint96 public carolsVaultId = 2;

  event Liquidate(uint256 _vaultId, address _assetAddress, uint256 _usdaToRepurchase, uint256 _tokensToLiquidate);
  event BorrowUSDA(uint256 _vaultId, address _vaultAddress, uint256 _borrowAmount, uint256 _fee);

  function setUp() public override {
    super.setUp();

    // Bob mints vault
    _mintVault(bob);
    // Since we only have 1 vault the id: 1 is gonna be Bob's vault
    bobVault = IVault(vaultController.vaultIdVaultAddress(bobsVaultId));

    vm.startPrank(bob);
    weth.approve(address(bobVault), bobWETH);
    bobVault.depositERC20(address(weth), bobWETH);
    vm.stopPrank();

    // Carol mints vault
    _mintVault(carol);
    // Since we only have 2 vaults the id: 2 is gonna be Carol's vault
    carolVault = IVault(vaultController.vaultIdVaultAddress(carolsVaultId));

    vm.startPrank(carol);
    uni.approve(address(carolVault), carolUni);
    carolVault.depositERC20(address(uni), carolUni);
    vm.stopPrank();

    _mintVault(dave);
    daveVault = IVault(vaultController.vaultIdVaultAddress(3));
  }

   function testLiquidateVault() public {
    uint192 _accountBorrowingPower = vaultController.vaultBorrowingPower(bobsVaultId);
    uint256 _vaultInitialWethBalance = bobVault.balances(WETH_ADDRESS);

    // Borrow the maximum amount
    vm.prank(bob);
    vaultController.borrowUSDA(bobsVaultId, _accountBorrowingPower);

    // Let time pass so the vault becomes liquidatable because of interest
    uint256 _tenYears = 10 * (365 days + 6 hours);
    vm.warp(block.timestamp + _tenYears);

    // Calculate interest to update the protocol, vault should now be liquidatable
    vaultController.calculateInterest();

    // Advance time so the price is stale
    vm.warp(block.timestamp + staleTime + 1);

    uint256 _liquidatableTokens = vaultController.tokensToLiquidate(bobsVaultId, WETH_ADDRESS);
    uint256 _daveUSDA = 1_000_000 ether;
    // Liquidate vault
    vm.startPrank(dave);
    susd.approve(address(usdaToken), _daveUSDA);
    usdaToken.deposit(_daveUSDA);
    uint256 _liquidated = 0;
    uint256 numVaults = vaultController.vaultsMinted();
    for(uint256 vaultId=1; vaultId<numVaults+1; vaultId++){
      console.log(vaultId);
      bool peekCheckVault = vaultController.peekCheckVault(uint96(vaultId));
      console.log(peekCheckVault);
      // if the vault is undercollateralized, attemt to liquidate it
      if (!peekCheckVault) {
        // get vault info
        IVaultController.VaultSummary[] memory vaultSummary = vaultController.vaultSummaries(uint96(vaultId), uint96(vaultId));
        for(uint256 j = 0; j<vaultSummary.length; j++){
          address tokenAddr = vaultSummary[j].tokenAddresses[0];
          console.log(tokenAddr);
          if(_vaultInitialWethBalance > 0) {
            _liquidated += vaultController.liquidateVault(bobsVaultId, WETH_ADDRESS, _vaultInitialWethBalance);
          }
        }
      }
    }
    vm.stopPrank();

    // Only the max liquidatable amount should be liquidated
    assertEq(_liquidated, _liquidatableTokens);
  }
}
