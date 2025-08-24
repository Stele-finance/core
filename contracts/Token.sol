// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract Token is ERC20, ERC20Permit, ERC20Votes {
    bool private _mintingFinished = false;
    
    // Minting finished event
    event MintingFinished();
    
    // Set total supply in constructor and finish minting
    constructor() ERC20("Stele", "STL") ERC20Permit("Stele") {
        _mint(msg.sender, 100000000 * 10**18);
        _finishMinting();
    }

    function _finishMinting() private {
        _mintingFinished = true;
        emit MintingFinished();
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        // Prevent minting after initial supply creation except from constructor
        if (_mintingFinished) {
            require(msg.sender == address(this), "Token: minting is finished");
        }
        super._mint(to, amount);
    }

    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }
}