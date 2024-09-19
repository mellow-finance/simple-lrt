
from web3 import Web3
import os
import json

from dotenv import load_dotenv

load_dotenv()


w3 = Web3(Web3.HTTPProvider(os.getenv('MAINNET_RPC')))


vaults = [
    '0xBEEF69Ac7870777598A04B2bd4771c71212E6aBc',
    '0x84631c0d0081FDe56DeB72F6DE77abBbF6A9f93a',
    '0x5fD13359Ba15A84B76f7F87568309040176167cd',
    '0x7a4EffD87C2f3C55CA251080b1343b605f327E3a',
    '0x49cd586dd9BA227Be9654C735A659a1dB08232a9',
    '0x82dc3260f599f4fC4307209A1122B6eAa007163b',
    '0xd6E09a5e6D719d1c881579C9C8670a210437931b',
    '0x8c9532a60E0E7C6BbD2B2c1303F63aCE1c3E9811',
    '0x7b31F008c48EFb65da78eA0f255EE424af855249',
    '0x4f3Cc6359364004b245ad5bE36E6ad4e805dC961'
]

from_block = 20045981
to_block = w3.eth.block_number
block_step = 10000

for vault in vaults:    
    balances = set()
    approvals = set()
    for block in range(from_block, to_block, block_step):
        transfer_events = w3.eth.get_logs({
            'fromBlock': block,
            'toBlock': min(block + block_step, to_block),
            'address': vault,
            'topics': ['0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef'] # Transfer(address,address,uint256)
        })
        for event in transfer_events:
            from_user = '0x' + event.topics[1][-20:].hex()
            to_user = '0x' + event.topics[2][-20:].hex()
            balances.add(from_user)
            balances.add(to_user)
        
        approve_events = w3.eth.get_logs({
            'fromBlock': block,
            'toBlock': min(block + block_step, to_block),
            'address': vault,
            'topics': ['0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925'] # Approval(address,address,uint256)
        })
        for event in approve_events:
            from_user = '0x' + event.topics[1][-20:].hex()
            to_user = '0x' + event.topics[2][-20:].hex()
            approvals.add((from_user, to_user))

    print(f'Vault {vault} has {len(balances)} unique users and {len(approvals)} unique approvals')
    
    users_array = 'address[] public users = [{}];'
    users_array = users_array.format(', '.join(balances))

    if len(approvals_from_array):
        approvals_from_array = 'address[] public approvalsFrom = [{}];'
        approvals_to_array = 'address[] public approvalsTo = [{}];'
        approvals_from_array = approvals_from_array.format(', '.join([a[0] for a in approvals]))
        approvals_to_array = approvals_to_array.format(', '.join([a[1] for a in approvals]))
    else:
        approvals_from_array = 'address[] public approvalsFrom;'
        approvals_to_array = 'address[] public approvalsTo;'
    
    template = '''
// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

conract Users_{} {{
    // Possible users with non-zero balances
    {}
    // Possible users with non-zero `from` approvals
    {}
    // Possible users with non-zero `to` approvals
    {}
}}'''
    with open(f'./test/migration/Users_{vault}.sol', 'w') as f:
        f.write(template.format(vault, users_array, approvals_from_array, approvals_to_array))