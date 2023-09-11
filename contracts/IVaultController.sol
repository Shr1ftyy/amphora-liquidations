// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/// @title VaultController Interface
interface IVaultController {
  /*///////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/
  /**
   * @notice Emited when payInterest is called to accrue interest and distribute it
   * @param _epoch The block timestamp when the function called
   * @param _amount The increase amount of the interest factor
   * @param _curveVal The value at the curve
   */
  event InterestEvent(uint64 _epoch, uint192 _amount, uint256 _curveVal);

  /**
   * @notice Emited when a new protocol fee is being set
   * @param _protocolFee The new fee for the protocol
   */
  event NewProtocolFee(uint192 _protocolFee);

  /**
   * @notice Emited when a new erc20 token is being registered as acceptable collateral
   * @param _tokenAddress The addres of the erc20 token
   * @param _ltv The loan to value amount of the erc20
   * @param _oracleAddress The address of the oracle to use to fetch the price
   * @param _liquidationIncentive The liquidation penalty for the token
   * @param _cap The maximum amount that can be deposited
   */
  event RegisteredErc20(
    address _tokenAddress, uint256 _ltv, address _oracleAddress, uint256 _liquidationIncentive, uint256 _cap
  );

  /**
   * @notice Emited when the information about an acceptable erc20 token is being update
   * @param _tokenAddress The addres of the erc20 token to update
   * @param _ltv The new loan to value amount of the erc20
   * @param _oracleAddress The new address of the oracle to use to fetch the price
   * @param _liquidationIncentive The new liquidation penalty for the token
   * @param _cap The maximum amount that can be deposited
   * @param _poolId The convex pool id of a crv lp token
   */
  event UpdateRegisteredErc20(
    address _tokenAddress,
    uint256 _ltv,
    address _oracleAddress,
    uint256 _liquidationIncentive,
    uint256 _cap,
    uint256 _poolId
  );

  /**
   * @notice Emited when a new vault is being minted
   * @param _vaultAddress The address of the new vault
   * @param _vaultId The id of the vault
   * @param _vaultOwner The address of the owner of the vault
   */
  event NewVault(address _vaultAddress, uint256 _vaultId, address _vaultOwner);

  /**
   * @notice Emited when the owner registers a curve master
   * @param _curveMasterAddress The address of the curve master
   */
  event RegisterCurveMaster(address _curveMasterAddress);
  /**
   * @notice Emited when someone successfully borrows USDA
   * @param _vaultId The id of the vault that borrowed against
   * @param _vaultAddress The address of the vault that borrowed against
   * @param _borrowAmount The amounnt that was borrowed
   * @param _fee The fee assigned to the treasury
   */
  event BorrowUSDA(uint256 _vaultId, address _vaultAddress, uint256 _borrowAmount, uint256 _fee);

  /**
   * @notice Emited when someone successfully repayed a vault's loan
   * @param _vaultId The id of the vault that was repayed
   * @param _vaultAddress The address of the vault that was repayed
   * @param _repayAmount The amount that was repayed
   */
  event RepayUSDA(uint256 _vaultId, address _vaultAddress, uint256 _repayAmount);

  /**
   * @notice Emited when someone successfully liquidates a vault
   * @param _vaultId The id of the vault that was liquidated
   * @param _assetAddress The address of the token that was liquidated
   * @param _usdaToRepurchase The amount of USDA that was repurchased
   * @param _tokensToLiquidate The number of tokens that were taken from the vault and sent to the liquidator
   * @param _liquidationFee The number of tokens that were taken from the fee and sent to the treasury
   */
  event Liquidate(
    uint256 _vaultId,
    address _assetAddress,
    uint256 _usdaToRepurchase,
    uint256 _tokensToLiquidate,
    uint256 _liquidationFee
  );

  /**
   * @notice Emited when the owner registers the USDA contract
   * @param _usdaContractAddress The address of the USDA contract
   */
  event RegisterUSDA(address _usdaContractAddress);

  /**
   * @notice Emited when governance changes the initial borrowing fee
   *  @param _oldBorrowingFee The old borrowing fee
   *  @param _newBorrowingFee The new borrowing fee
   */
  event ChangedInitialBorrowingFee(uint192 _oldBorrowingFee, uint192 _newBorrowingFee);

  /**
   * @notice Emited when governance changes the liquidation fee
   *  @param _oldLiquidationFee The old liquidation fee
   *  @param _newLiquidationFee The new liquidation fee
   */
  event ChangedLiquidationFee(uint192 _oldLiquidationFee, uint192 _newLiquidationFee);

  /**
   * @notice Emited when collaterals are migrated from old vault controller
   *  @param _oldVaultController The old vault controller migrated from
   *  @param _tokenAddresses The list of new collaterals
   */
  event CollateralsMigratedFrom(IVaultController _oldVaultController, address[] _tokenAddresses);

  /*///////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

  /// @notice Thrown when _msgSender is not the pauser of the contract
  error VaultController_OnlyPauser();

  /// @notice Thrown when the fee is too large
  error VaultController_FeeTooLarge();

  /// @notice Thrown when oracle does not exist
  error VaultController_OracleNotRegistered();

  /// @notice Thrown when the token is already registered
  error VaultController_TokenAlreadyRegistered();

  /// @notice Thrown when the token is not registered
  error VaultController_TokenNotRegistered();

  /// @notice Thrown when the _ltv is incompatible
  error VaultController_LTVIncompatible();

  /// @notice Thrown when _msgSender is not the minter
  error VaultController_OnlyMinter();

  /// @notice Thrown when vault is insolvent
  error VaultController_VaultInsolvent();

  /// @notice Thrown when repay is grater than borrow
  error VaultController_RepayTooMuch();

  /// @notice Thrown when trying to liquidate 0 tokens
  error VaultController_LiquidateZeroTokens();

  /// @notice Thrown when trying to liquidate more than is possible
  error VaultController_OverLiquidation();

  /// @notice Thrown when vault is solvent
  error VaultController_VaultSolvent();

  /// @notice Thrown when vault does not exist
  error VaultController_VaultDoesNotExist();

  /// @notice Thrown when migrating collaterals to a new vault controller
  error VaultController_WrongCollateralAddress();

  /// @notice Thrown when a not valid vault is trying to modify the total deposited
  error VaultController_NotValidVault();

  /// @notice Thrown when a deposit surpass the cap
  error VaultController_CapReached();

  /// @notice Thrown when registering a crv lp token with wrong address
  error VaultController_TokenAddressDoesNotMatchLpAddress();

  /*///////////////////////////////////////////////////////////////
                            ENUMS
  //////////////////////////////////////////////////////////////*/

  enum CollateralType {
    Single,
    CurveLPStakedOnConvex
  }

  /*///////////////////////////////////////////////////////////////
                            STRUCTS
    //////////////////////////////////////////////////////////////*/

  struct VaultSummary {
    uint96 id;
    uint192 borrowingPower;
    uint192 vaultLiability;
    address[] tokenAddresses;
    uint256[] tokenBalances;
  }

  struct Interest {
    uint64 lastTime;
    uint192 factor;
  }

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
    //////////////////////////////////////////////////////////////*/

  /// @notice Total number of tokens registered
  function tokensRegistered() external view returns (uint256 _tokensRegistered);

  /// @notice Total number of minted vaults
  function vaultsMinted() external view returns (uint96 _vaultsMinted);

  /// @notice Returns the block timestamp when pay interest was last called
  /// @return _lastInterestTime The block timestamp when pay interest was last called
  function lastInterestTime() external view returns (uint64 _lastInterestTime);

  /// @notice Total base liability
  function totalBaseLiability() external view returns (uint192 _totalBaseLiability);

  /// @notice Returns the latest interest factor
  /// @return _interestFactor The latest interest factor
  function interestFactor() external view returns (uint192 _interestFactor);

  /// @notice The protocol's fee
  function protocolFee() external view returns (uint192 _protocolFee);

  /// @notice The max allowed to be set as borrowing fee
  function MAX_INIT_BORROWING_FEE() external view returns (uint192 _maxInitBorrowingFee);

  /// @notice The initial borrowing fee (1e18 == 100%)
  function initialBorrowingFee() external view returns (uint192 _initialBorrowingFee);

  /// @notice The fee taken from the liquidator profit (1e18 == 100%)
  function liquidationFee() external view returns (uint192 _liquidationFee);

  /// @notice Returns an array of all the vault ids a specific wallet has
  /// @param _wallet The address of the wallet to target
  /// @return _vaultIDs The ids of the vaults the wallet has
  function vaultIDs(address _wallet) external view returns (uint96[] memory _vaultIDs);

  /// @notice Returns an array of all enabled tokens
  /// @return _enabledToken The array containing the token addresses
  function enabledTokens(uint256 _index) external view returns (address _enabledToken);

  /// @notice Returns the token id given a token's address
  /// @param _tokenAddress The address of the token to target
  /// @return _tokenId The id of the token
  function tokenId(address _tokenAddress) external view returns (uint256 _tokenId);

  /// @notice Returns the ltv of a given token address
  /// @param _tokenAddress The address of the token
  /// @return _ltv The loan-to-value of a token
  function tokenLTV(address _tokenAddress) external view returns (uint256 _ltv);

  /// @notice Returns the liquidation incentive of an accepted token collateral
  /// @param _tokenAddress The address of the token
  /// @return _liquidationIncentive The liquidation incentive of the token
  function tokenLiquidationIncentive(address _tokenAddress) external view returns (uint256 _liquidationIncentive);

  /// @notice Returns the cap of a given token address
  /// @param _tokenAddress The address of the token
  /// @return _cap The cap of the token
  function tokenCap(address _tokenAddress) external view returns (uint256 _cap);

  /// @notice Returns the total deposited of a given token address
  /// @param _tokenAddress The address of the token
  /// @return _totalDeposited The total deposited of a token
  function tokenTotalDeposited(address _tokenAddress) external view returns (uint256 _totalDeposited);

  /// @notice Returns the collateral type of a token
  /// @param _tokenAddress The address of the token
  /// @return _type The collateral type of a token
  function tokenCollateralType(address _tokenAddress) external view returns (CollateralType _type);

  /// @notice Returns the pool id of a curve LP type token
  /// @dev    If the token is not of type CurveLPStakedOnConvex then it returns 0
  /// @param _tokenAddress The address of the token
  /// @return _poolId The pool id of a curve LP type token
  function tokenPoolId(address _tokenAddress) external view returns (uint256 _poolId);

  /// @notice Returns an array of all enabled tokens
  /// @return _enabledTokens The array containing the token addresses
  function getEnabledTokens() external view returns (address[] memory _enabledTokens);

  /// @notice Returns the address of a vault given it's id
  /// @param _vaultID The id of the vault to target
  /// @return _vaultAddress The address of the targetted vault
  function vaultIdVaultAddress(uint96 _vaultID) external view returns (address _vaultAddress);

  /*///////////////////////////////////////////////////////////////
                            LOGIC
    //////////////////////////////////////////////////////////////*/

  /// @notice Returns the amount of USDA needed to reach even solvency without state changes
  /// @dev This amount is a moving target and changes with each block as payInterest is called
  /// @param _id The id of vault we want to target
  /// @return _usdaToSolvency The amount of USDA needed to reach even solvency
  function amountToSolvency(uint96 _id) external view returns (uint256 _usdaToSolvency);

  /// @notice Returns the calculated amount of tokens to liquidate for a vault
  /// @dev The amount of tokens owed is a moving target and changes with each block as payInterest is called
  ///      This function can serve to give an indication of how many tokens can be liquidated
  ///      All this function does is call _liquidationMath with 2**256-1 as the amount
  /// @param _id The id of vault we want to target
  /// @param _token The address of token to calculate how many tokens to liquidate
  /// @return _tokensToLiquidate The amount of tokens liquidatable
  function tokensToLiquidate(uint96 _id, address _token) external view returns (uint256 _tokensToLiquidate);

  /// @notice Check a vault for over-collateralization
  /// @dev This function calls peekVaultBorrowingPower so no state change is done
  /// @param _id The id of vault we want to target
  /// @return _overCollateralized Returns true if vault over-collateralized; false if vault under-collaterlized
  function peekCheckVault(uint96 _id) external view returns (bool _overCollateralized);

  /// @notice Check a vault for over-collateralization
  /// @dev This function calls getVaultBorrowingPower to allow state changes to happen if an oracle need them
  /// @param _id The id of vault we want to target
  /// @return _overCollateralized Returns true if vault over-collateralized; false if vault under-collaterlized
  function checkVault(uint96 _id) external returns (bool _overCollateralized);

  /// @notice Returns the status of a range of vaults
  /// @dev Special view only function to help liquidators
  /// @param _start The id of the vault to start looping
  /// @param _stop The id of vault to stop looping
  /// @return _vaultSummaries An array of vault information
  function vaultSummaries(uint96 _start, uint96 _stop) external view returns (VaultSummary[] memory _vaultSummaries);

  /// @notice Creates a new vault and returns it's address
  /// @return _vaultAddress The address of the newly created vault
  function mintVault() external returns (address _vaultAddress);

  /// @notice Simulates the liquidation of an underwater vault
  /// @dev Returns all zeros if vault is solvent
  /// @param _id The id of vault we want to target
  /// @param _assetAddress The address of the token the liquidator wishes to liquidate
  /// @param _tokensToLiquidate The number of tokens to liquidate
  /// @return _collateralLiquidated The number of collateral tokens the liquidator will receive
  /// @return _usdaPaid The amount of USDA the liquidator will have to pay
  function simulateLiquidateVault(
    uint96 _id,
    address _assetAddress,
    uint256 _tokensToLiquidate
  ) external view returns (uint256 _collateralLiquidated, uint256 _usdaPaid);

  /// @notice Liquidates an underwater vault
  /// @dev Pays interest before liquidation. Vaults may be liquidated up to the point where they are exactly solvent
  /// @param _id The id of vault we want to target
  /// @param _assetAddress The address of the token the liquidator wishes to liquidate
  /// @param _tokensToLiquidate The number of tokens to liquidate
  /// @return _toLiquidate The number of tokens that got liquidated
  function liquidateVault(
    uint96 _id,
    address _assetAddress,
    uint256 _tokensToLiquidate
  ) external returns (uint256 _toLiquidate);

  function paused() external view returns (bool _paused);
}
