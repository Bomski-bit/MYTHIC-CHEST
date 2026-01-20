**THIS CHECKLIST IS NOT COMPLETE**. Use `--show-ignored-findings` to show all the results.
Summary
 - [arbitrary-send-eth](#arbitrary-send-eth) (1 results) (High)
 - [encode-packed-collision](#encode-packed-collision) (2 results) (High)
 - [incorrect-equality](#incorrect-equality) (1 results) (Medium)
 - [uninitialized-local](#uninitialized-local) (1 results) (Medium)
 - [reentrancy-benign](#reentrancy-benign) (1 results) (Low)
 - [reentrancy-events](#reentrancy-events) (2 results) (Low)
 - [pragma](#pragma) (1 results) (Informational)
 - [low-level-calls](#low-level-calls) (1 results) (Informational)
 - [missing-inheritance](#missing-inheritance) (2 results) (Informational)
 - [naming-convention](#naming-convention) (15 results) (Informational)
 - [unused-state](#unused-state) (1 results) (Informational)
## arbitrary-send-eth
Impact: High
Confidence: Medium
 - [ ] ID-0
[MythicChest.rescueETH(address,uint256)](src/MythicChest.sol#L404-L410) sends eth to arbitrary user
	Dangerous calls:
	- [(success,None) = address(_to).call{value: _amount}()](src/MythicChest.sol#L407)

src/MythicChest.sol#L404-L410


## encode-packed-collision
Impact: High
Confidence: High
 - [ ] ID-1
[Chest.uri(uint256)](src/Chest.sol#L70-L72) calls abi.encodePacked() with multiple dynamic arguments:
	- [string(abi.encodePacked(super.uri(tokenId),tokenId.toString(),.json))](src/Chest.sol#L71)

src/Chest.sol#L70-L72


 - [ ] ID-2
[Prizes.uri(uint256)](src/Prizes.sol#L137-L139) calls abi.encodePacked() with multiple dynamic arguments:
	- [string(abi.encodePacked(baseMetadataURI,_id.toString(),.json))](src/Prizes.sol#L138)

src/Prizes.sol#L137-L139


## incorrect-equality
Impact: Medium
Confidence: High
 - [ ] ID-3
[MythicChest.withdrawRevenue(address)](src/MythicChest.sol#L371-L381) uses a dangerous strict equality:
	- [balance == 0](src/MythicChest.sol#L376)

src/MythicChest.sol#L371-L381


## uninitialized-local
Impact: Medium
Confidence: Medium
 - [ ] ID-4
[MythicChest.fulfillRandomWords(uint256,uint256[]).prizeCounts](src/MythicChest.sol#L271) is a local variable never initialized

src/MythicChest.sol#L271


## reentrancy-benign
Impact: Low
Confidence: Medium
 - [ ] ID-5
Reentrancy in [MythicChest.openChest(uint256)](src/MythicChest.sol#L241-L257):
	External calls:
	- [I_CHEST.burn(msg.sender,CHEST_ID,amount)](src/MythicChest.sol#L246)
	- [requestId = VRF_COORDINATOR.requestRandomWords(KEY_HASH,SUBSCRIPTION_ID,REQUEST_CONFIRMATIONS,CALLBACK_GAS_LIMIT,uint32(amount))](src/MythicChest.sol#L249-L251)
	State variables written after the call(s):
	- [requestIdToRequest[requestId] = ChestRequest({opener:msg.sender,amount:amount})](src/MythicChest.sol#L254)

src/MythicChest.sol#L241-L257


## reentrancy-events
Impact: Low
Confidence: Medium
 - [ ] ID-6
Reentrancy in [MythicChest.fulfillRandomWords(uint256,uint256[])](src/MythicChest.sol#L265-L311):
	External calls:
	- [I_PRIZES.mintBatch(request.opener,distinctIds,distinctAmounts,)](src/MythicChest.sol#L304)
	Event emitted after the call(s):
	- [PrizeDropped(request.opener,distinctIds[i_scope_0],distinctAmounts[i_scope_0])](src/MythicChest.sol#L309)

src/MythicChest.sol#L265-L311


 - [ ] ID-7
Reentrancy in [MythicChest.rescueETH(address,uint256)](src/MythicChest.sol#L404-L410):
	External calls:
	- [(success,None) = address(_to).call{value: _amount}()](src/MythicChest.sol#L407)
	Event emitted after the call(s):
	- [EthRescued(_to,_amount)](src/MythicChest.sol#L409)

src/MythicChest.sol#L404-L410
