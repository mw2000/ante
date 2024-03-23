// Create a Mock ERC20 token

pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("MOCK", "MOCK") {}

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }
}