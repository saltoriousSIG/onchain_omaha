// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 <0.9.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./hands.sol";

// TODO create events;

contract OnchainOmahaGame is Ownable { 
    address buy_in_token;
    uint256 buy_in_token_decimals;
    uint256 buy_in_amount;
    uint256 total_collected;
    uint256 game_count;
    Hands hands_contract;

    event GameStarted(uint256 indexed game_id);  
    event HandBought(uint256 indexed game_id, address indexed user, uint256 indexed token_id, uint256 fid);
    event HandFolded(uint256 indexed game_id, address indexed user, uint256 indexed token_id, uint256 refund_amount);
    event GameEnded(uint256 indexed game_id, address[] winners);
    event Claimed(uint256 indexed game_id, address indexed user, uint256 amount);
    

    enum GameState { 
        ACTIVE, 
        COMPLETED
    }

    struct Participant { 
        uint256 token_id;
        uint256 fid;
    }

    struct Winner { 
        uint256 amount_won;
        bool claimed;
    }

    struct Game { 
        mapping(address => Participant) participants;
        address[] participant_list;
        uint256 game_pot;
        uint256 hand_count;
        GameState state;
        uint256[] hands_in_game;
        mapping(address => Winner) winner;
        
    }

    mapping(uint256 => Game) public games;

    constructor(address _owner, address _buy_in_token, uint256 _buy_in_amount, uint256 _buy_in_token_decimals) Ownable(_owner) {
        hands_contract = new Hands("Onchain Omaha", "OMAHA", address(this));
        buy_in_token = _buy_in_token;
        buy_in_amount = _buy_in_amount;
        buy_in_token_decimals = _buy_in_token_decimals;
    }

    function update_buy_in_token(address token, uint256 decimals) public onlyOwner { 
        buy_in_token = token;
        buy_in_token_decimals = decimals;
    }

    function update_buy_in_amount(uint256 amount) public onlyOwner{ 
        buy_in_amount = amount;
    }

    function fetch_buy_in() public view returns(uint256 buy_in) { 
        buy_in = buy_in_amount; 
    }

    function fetch_hands_address() public view returns(address hands_address) { 
        return address(hands_contract);
    }

    function fetch_buy_token() public view returns(address token) { 
        token = buy_in_token; 
    } 

    function fetch_game_participant_data(uint256 game_id, address user) public view returns(uint256 token_id, uint256 fid) { 
        Game storage game = games[game_id];
        token_id = game.participants[user].token_id;
        fid = game.participants[user].fid;
    }

    function fetch_participant_list(uint256 game_id) public view returns(address[] memory participants) { 
        Game storage game = games[game_id];
        participants = game.participant_list;
    }

    // start game
    function start_game() public onlyOwner { 
        Game storage new_game = games[game_count];
        new_game.game_pot = 0;
        new_game.state = GameState.ACTIVE;
        emit GameStarted(game_count); 
    }

    // buy hand
    //TODO: set total pot value
    function buy_hand(uint256 game_id, uint256 fid, string calldata uri) public returns(uint256 token_id) { 
        require(buy_in_amount > 0, "Required buy in value");
        Game storage game = games[game_id];
        require(game.state == GameState.ACTIVE, "Game not active");
        require(game.hand_count <= 10, "max hands");

        uint256 allowance = IERC20(buy_in_token).allowance(msg.sender, address(this));
        require(allowance >= buy_in_amount, "Allowance not met");

        game.participants[msg.sender] = Participant(
            token_id,
            fid
        );
        game.game_pot += buy_in_amount;
        game.hands_in_game.push(token_id);
        game.hand_count++;
        game.participant_list.push(msg.sender);

        IERC20(buy_in_token).transferFrom(msg.sender, address(this), buy_in_amount);
        token_id = hands_contract.mint(msg.sender, uri);

        emit HandBought(game_id, msg.sender, token_id, fid);
    }

    // fold hand
    function fold_hand(uint256 game_id, uint256 token_id) public { 
        address hand_owner = hands_contract.ownerOf(token_id);
        require(hand_owner == msg.sender, "Sender doesn't own hand");

        Game storage game = games[game_id];
        require(game.state == GameState.ACTIVE, "Game not active");

        uint256 return_amount = (buy_in_amount * 90) / 10 ** buy_in_token_decimals;
        game.game_pot -= return_amount;
        game.hand_count--;

        delete game.participants[msg.sender];
        for (uint256 i = 0; i < game.participant_list.length - 1; i++) {
            if (game.participant_list[i] == msg.sender) { 
                game.participant_list[i] = game.participant_list[i + 1];
                game.participant_list.pop();
            }
        }
        for (uint256 i = 0; i < game.hands_in_game.length - 1; i++) {
            if (game.hands_in_game[i] == token_id) { 
                game.hands_in_game[i] = game.hands_in_game[i + 1];
                game.hands_in_game.pop();
            }
        }

        IERC20(buy_in_token).transferFrom(address(this), msg.sender, return_amount);
        emit HandBought(game_id, msg.sender, token_id, return_amount);
    }

    // end game

    function end_game(uint256 game_id, address[] calldata _winners) public onlyOwner  { 
        Game storage game = games[game_id];
        require(game.state == GameState.ACTIVE, "Game not active");

        uint256 num_winners = _winners.length;
        uint256 payout = game.game_pot / num_winners;

        for (uint256 i = 0; i < _winners.length; i++) { 
            game.winner[_winners[i]] = Winner(
                payout,
                false
            );
        } 

        game.state = GameState.COMPLETED;
        game_count++;
        emit GameEnded(game_id, _winners);
    }

    // claim
    function claim(uint256 game_id) public { 
        Game storage game = games[game_id];
        require(game.state == GameState.COMPLETED, "Game not completed");
        require(!game.winner[msg.sender].claimed, "Already claimed");

        if(game.winner[msg.sender].amount_won > 0) { 
            IERC20(buy_in_token).transferFrom(address(this), msg.sender, game.winner[msg.sender].amount_won);
            emit Claimed(game_id, msg.sender, game.winner[msg.sender].amount_won);
        }

    }
}