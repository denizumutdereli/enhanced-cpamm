// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract CPAMM is Initializable, OwnableUpgradeable, ERC20BurnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public tokenA;
    IERC20Upgradeable public tokenB;

    uint256 constant WAD = 1e18;
    uint256 constant FEE_DENOMINATOR = 1000;
    uint256 constant FEE_NUMERATOR = 997;
    uint256 constant MINIMUM_LIQUIDITY = 1000;

    uint256 public poolDecimals;
    uint256 public decimalsA;
    uint256 public decimalsB;

    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public blockTimestampLast;

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;

    address public feeRecipient;

    struct POOL {
        string name;
        string symbol;
        address tokenA;
        address tokenB;
        uint256 poolDecimals;
        uint256 tokenADecimals;
        uint256 tokenBDecimals;
    }

    event Swap(address indexed user, address indexed tokenIn, uint256 amountIn, uint256 amountOut);
    event AddLiquidity(address indexed user, uint256 amountA, uint256 amountB, uint256 shares);
    event RemoveLiquidity(address indexed user, uint256 shares, uint256 amountA, uint256 amountB);
    event RescueToken(address indexed token, address indexed to, uint256 amount);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event Sync(uint256 reserveA, uint256 reserveB);

    error InvalidConstructorParameters();
    error InvalidTokenAddress();
    error ZeroAmount();
    error DyDxNotEqualYDivX();
    error ZeroShares();
    error DirectCallNotAllowed();
    error DeadlineExpired();
    error SlippageExceeded();
    error InsufficientLiquidity();
    error InvalidFeeRecipient();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(POOL memory _pool) public initializer {
        __Ownable_init(msg.sender);
        __ERC20_init(_pool.name, _pool.symbol);
        __ReentrancyGuard_init();
        __Pausable_init();

        if (_pool.tokenA == address(0) || _pool.tokenB == address(0) || _pool.poolDecimals > 18)
            revert InvalidConstructorParameters();

        tokenA = IERC20Upgradeable(_pool.tokenA);
        tokenB = IERC20Upgradeable(_pool.tokenB);
        poolDecimals = _pool.poolDecimals;
        decimalsA = _pool.tokenADecimals;
        decimalsB = _pool.tokenBDecimals;
        feeRecipient = msg.sender;
    }

    function decimals() public view override returns (uint8) {
        return uint8(poolDecimals);
    }

    function _update(uint256 _reserveA, uint256 _reserveB) private {
        reserveA = _reserveA;
        reserveB = _reserveB;

        if (blockTimestampLast != 0) {
            uint256 timeElapsed = block.timestamp - blockTimestampLast;
            if (timeElapsed > 0 && _reserveA != 0 && _reserveB != 0) {
                price0CumulativeLast += uint256(_reserveB / _reserveA) * timeElapsed;
                price1CumulativeLast += uint256(_reserveA / _reserveB) * timeElapsed;
            }
        }
        blockTimestampLast = block.timestamp;

        emit Sync(_reserveA, _reserveB);
    }

    function getTotalReserves() external view returns (uint256, uint256) {
        return (reserveA, reserveB);
    }

    function getTokenPair() external view returns (address, address) {
        return (address(tokenA), address(tokenB));
    }

    function getPrice() external view returns (uint256 price0, uint256 price1) {
        price0 = uint256(reserveB * WAD / reserveA);
        price1 = uint256(reserveA * WAD / reserveB);
    }

    function swap(
        address _tokenIn,
        uint256 _amountIn,
        uint256 _minAmountOut,
        uint256 _deadline
    ) external nonReentrant whenNotPaused returns (uint256 amountOut) {
        if (block.timestamp > _deadline) revert DeadlineExpired();
        if (_tokenIn != address(tokenA) && _tokenIn != address(tokenB)) revert InvalidTokenAddress();
        if (_amountIn == 0) revert ZeroAmount();

        bool isTokenA = _tokenIn == address(tokenA);
        (IERC20Upgradeable tokenIn, IERC20Upgradeable tokenOut, uint256 reserveIn, uint256 reserveOut) = isTokenA
            ? (tokenA, tokenB, reserveA, reserveB)
            : (tokenB, tokenA, reserveB, reserveA);

        tokenIn.safeTransferFrom(msg.sender, address(this), _amountIn);

        uint256 amountInWithFee = (_amountIn * FEE_NUMERATOR) / FEE_DENOMINATOR;
        amountOut = (reserveOut * amountInWithFee) / (reserveIn + amountInWithFee);

        if (amountOut < _minAmountOut) revert SlippageExceeded();

        tokenOut.safeTransfer(msg.sender, amountOut);
        _update(tokenA.balanceOf(address(this)), tokenB.balanceOf(address(this)));

        emit Swap(msg.sender, _tokenIn, _amountIn, amountOut);
    }

    function addLiquidity(
        uint256 _amountA,
        uint256 _amountB,
        uint256 _minShares,
        uint256 _deadline
    ) external nonReentrant whenNotPaused returns (uint256 shares) {
        if (block.timestamp > _deadline) revert DeadlineExpired();
        if (_amountA == 0 || _amountB == 0) revert ZeroAmount();

        tokenA.safeTransferFrom(msg.sender, address(this), _amountA);
        tokenB.safeTransferFrom(msg.sender, address(this), _amountB);

        uint256 balanceA = tokenA.balanceOf(address(this));
        uint256 balanceB = tokenB.balanceOf(address(this));

        uint256 amountA = balanceA - reserveA;
        uint256 amountB = balanceB - reserveB;

        uint256 _totalSupply = totalSupply();
        if (_totalSupply == 0) {
            shares = _sqrt(amountA * amountB) - MINIMUM_LIQUIDITY;
            _mint(address(1), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            shares = _min((amountA * _totalSupply) / reserveA, (amountB * _totalSupply) / reserveB);
        }

        if (shares < _minShares) revert SlippageExceeded();
        if (shares == 0) revert ZeroShares();

        _mint(msg.sender, shares);
        _update(balanceA, balanceB);

        emit AddLiquidity(msg.sender, amountA, amountB, shares);
    }

    function removeLiquidity(
        uint256 _shares,
        uint256 _minAmountA,
        uint256 _minAmountB,
        uint256 _deadline
    ) external nonReentrant whenNotPaused returns (uint256 amountA, uint256 amountB) {
        if (block.timestamp > _deadline) revert DeadlineExpired();
        if (_shares == 0) revert ZeroShares();

        uint256 balanceA = tokenA.balanceOf(address(this));
        uint256 balanceB = tokenB.balanceOf(address(this));

        uint256 _totalSupply = totalSupply();
        amountA = (_shares * balanceA) / _totalSupply;
        amountB = (_shares * balanceB) / _totalSupply;

        if (amountA < _minAmountA || amountB < _minAmountB) revert SlippageExceeded();
        if (amountA == 0 || amountB == 0) revert ZeroAmount();

        _burn(msg.sender, _shares);
        _update(balanceA - amountA, balanceB - amountB);

        tokenA.safeTransfer(msg.sender, amountA);
        tokenB.safeTransfer(msg.sender, amountB);

        emit RemoveLiquidity(msg.sender, _shares, amountA, amountB);
    }

    function setFeeRecipient(address _newRecipient) external onlyOwner {
        if (_newRecipient == address(0)) revert InvalidFeeRecipient();
        address oldRecipient = feeRecipient;
        feeRecipient = _newRecipient;
        emit FeeRecipientUpdated(oldRecipient, _newRecipient);
    }

    function collectFees() external {
        uint256 balanceA = tokenA.balanceOf(address(this));
        uint256 balanceB = tokenB.balanceOf(address(this));
        uint256 feeA = balanceA - reserveA;
        uint256 feeB = balanceB - reserveB;

        if (feeA > 0) tokenA.safeTransfer(feeRecipient, feeA);
        if (feeB > 0) tokenB.safeTransfer(feeRecipient, feeB);

        _update(balanceA - feeA, balanceB - feeB);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function rescueToken(address _token, address _to, uint256 _amount) external onlyOwner {
        IERC20Upgradeable(_token).safeTransfer(_to, _amount);
        emit RescueToken(_token, _to, _amount);
    }

    function _sqrt(uint256 y) private pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function _min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    receive() external payable {
        revert DirectCallNotAllowed();
    }

    fallback() external payable {
        revert DirectCallNotAllowed();
    }
}