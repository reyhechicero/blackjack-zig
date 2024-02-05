const std = @import("std");
const MAX_RANK: usize = 13;
const MAX_SUIT: usize = 4;

const ranks = [MAX_RANK]u8{ 'A', '2', '3', '4', '5', '6', '7', '8', '9', 'T', 'J', 'Q', 'K' };
const suits = [MAX_SUIT]u8{ 'C', 'S', 'H', 'D' };

const Card = struct {
    suit: u8,
    rank: u8,
};

const Score = struct {
    soft: u8,
    hard: u8,
};

const Hand = std.MultiArrayList(Card);

fn random(max: usize) usize {
    var prng: ?std.rand.Xoshiro256 = null;
    var seed: u8 = undefined;
    var rand: std.rand.Random = undefined;
    std.os.getrandom(std.mem.asBytes(&seed)) catch unreachable;
    prng = std.rand.DefaultPrng.init(seed);
    rand = prng.?.random();
    return rand.intRangeAtMost(usize, 0, max);
}

fn deal(allocator: std.mem.Allocator, inHand: *Hand, hand: *Hand) !void {
    var randSuit = random(MAX_SUIT - 1);
    var randRank = random(MAX_RANK - 1);
    var i: usize = 0;
    if (inHand.len == 0) {
        // std.debug.print("nothing dealt yet. dealing card: {c} {c}\n", .{ ranks[randRank], suits[randSuit] });
        try inHand.append(allocator, .{ .suit = suits[randSuit], .rank = ranks[randRank] });
        try hand.append(allocator, .{ .suit = suits[randSuit], .rank = ranks[randRank] });
        return;
    }
    outer: while (i < inHand.len) {
        const card = inHand.get(i);
        if (suits[randSuit] == card.suit and ranks[randRank] == card.rank) {
            std.debug.print("reroll.\n", .{});
            randSuit = random(MAX_SUIT - 1);
            randRank = random(MAX_RANK - 1);
            break :outer;
        }
        i += 1;
    }
    try inHand.append(allocator, .{ .suit = suits[randSuit], .rank = ranks[randRank] });
    try hand.append(allocator, .{ .suit = suits[randSuit], .rank = ranks[randRank] });
}

// find a better way to do this...
fn calcHand(hand: *Hand, score: *Score) void {
    var i: usize = 0;
    while (i < hand.len) : (i += 1) {
        const card = hand.get(i);
        switch (card.rank) {
            '2' => {
                score.hard += 2;
                score.soft += 2;
            },
            '3' => {
                score.hard += 3;
                score.soft += 3;
            },
            '4' => {
                score.hard += 4;
                score.soft += 4;
            },
            '5' => {
                score.hard += 5;
                score.soft += 5;
            },
            '6' => {
                score.hard += 6;
                score.soft += 6;
            },
            '7' => {
                score.hard += 7;
                score.soft += 7;
            },
            '8' => {
                score.hard += 8;
                score.soft += 8;
            },
            '9' => {
                score.hard += 9;
                score.soft += 9;
            },
            'T' => {
                score.hard += 10;
                score.soft += 10;
            },
            'J' => {
                score.hard += 10;
                score.soft += 10;
            },
            'Q' => {
                score.hard += 10;
                score.soft += 10;
            },
            'K' => {
                score.hard += 10;
                score.soft += 10;
            },
            'A' => {
                score.hard += 1;
                score.soft += 11;
            },
            else => {
                std.debug.print("oh nyo.\n", .{});
            },
        }
    }
}

fn nextLine(reader: anytype, buffer: []u8) !?[]const u8 {
    const line = (try reader.readUntilDelimiterOrEof(
        buffer,
        '\n',
    )) orelse return null;

    // trim annoying windows-only carriage return character
    if (@import("builtin").os.tag == .windows) {
        return std.mem.trimRight(u8, line, "\r");
    } else {
        return line;
    }
}

fn printHand(hand: *Hand, player: bool) void {
    var i: usize = 0;
    if (player == true) {
        std.debug.print("Hand:\n", .{});
    } else {
        std.debug.print("Dealer's Hand:\n", .{});
    }
    while (i != hand.len) : (i += 1) {
        const itercard = hand.get(i);
        std.debug.print("  {c} {c}\n", .{ itercard.rank, itercard.suit });
    }
}

fn resetGame(allocator: std.mem.Allocator, playerScore: *Score, dealerScore: *Score, hand: *Hand, dealer: *Hand, inHand: *Hand) void {
    var i: usize = 0;
    while (i < dealer.len - 1) : (i += 1) {
        dealer.orderedRemove(i);
    }
    i = 0;
    while (i < hand.len - 1) : (i += 1) {
        hand.orderedRemove(i);
    }
    i = 0;
    while (i < inHand.len - 1) : (i += 1) {
        inHand.orderedRemove(i);
    }
    // i = 0;
    playerScore.soft = 0;
    playerScore.hard = 0;
    dealerScore.soft = 0;
    dealerScore.hard = 0;
    inHand.shrinkAndFree(allocator, 0);
    dealer.shrinkAndFree(allocator, 0);
    hand.shrinkAndFree(allocator, 0);
}

fn zeroOut(playerScore: *Score, dealerScore: *Score) void {
    playerScore.soft = 0;
    playerScore.hard = 0;
    dealerScore.soft = 0;
    dealerScore.hard = 0;
}

pub fn main() !void {
    const stdin = std.io.getStdIn();
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    var money: i32 = 500;
    var bet: i32 = 0;
    var score: u8 = 0;
    var dealerFinal: u8 = 0;
    var i: usize = 0;
    var playerScore = Score{ .soft = 0, .hard = 0 };
    var dealerScore = Score{ .soft = 0, .hard = 0 };
    const menu =
        \\Enter your choice:
        \\1.) Hit
        \\2.) Stand
        \\Enter: 
    ;
    var quit: bool = false;
    var buf: [7]u8 = undefined;
    var inHand = Hand{};
    var hand = Hand{};
    var dealer = Hand{};
    defer inHand.deinit(allocator);
    defer hand.deinit(allocator);
    std.debug.print("enter 'q' to quit at anytime", .{});
    outer: while (!quit) {
        if (money <= 0) {
            std.debug.print("You are broke!\n", .{});
            break;
        }
        if (bet == 0) {
            zeroOut(&playerScore, &dealerScore);
            if (dealer.len == 0 and hand.len == 0) {
                var cards: usize = 0;
                while (cards < 2) : (cards += 1) {
                    try deal(allocator, &inHand, &hand);
                    try deal(allocator, &inHand, &dealer);
                }
            }
            var betBuf: [20]u8 = undefined;
            std.debug.print("You have: ${d}\n", .{money});
            std.debug.print("enter in your bet: ", .{});
            var betInput = (try nextLine(stdin.reader(), &betBuf)).?;
            if (std.mem.eql(u8, betInput, "q") == true) {
                quit = true;
                break;
            }
            bet = std.fmt.parseInt(i32, betInput, 10) catch {
                continue;
            };
            while (bet > money or bet <= 0) {
                bet = 0; // set to 0 because if the user puts in a negative number
                std.debug.print("You have: ${d}\n", .{money});
                std.debug.print("You betted: ${d}\n", .{bet});
                if (bet > money) {
                    std.debug.print("You don't have that much money!\n", .{});
                } else if (bet <= 0) {
                    std.debug.print("You can't bet negative or 0 dollars!\n", .{});
                }
                std.debug.print("enter in a valid bet: ", .{});
                betInput = (try nextLine(stdin.reader(), &betBuf)).?;
                if (std.mem.eql(u8, betInput, "q") == true) {
                    quit = true;
                    break :outer;
                }
                bet = std.fmt.parseInt(i32, betInput, 10) catch {
                    continue :outer;
                };
            }
            std.debug.print("money if you win: {d}\n", .{money + (bet * 2)});
        }
        const dealerCard = dealer.get(0);
        zeroOut(&playerScore, &dealerScore);
        calcHand(&hand, &playerScore);
        calcHand(&dealer, &dealerScore);
        // std.debug.print("dealer's score: {d}\n", .{dealerScore.soft});
        std.debug.print("Dealer's card: {c} {c}\n", .{ dealerCard.rank, dealerCard.suit });
        // printHand(&dealer, false);
        printHand(&hand, true);
        if (hand.len == 2 and playerScore.soft == 21) {
            // i = 0;
            if (dealerScore.soft == 21) {
                std.debug.print("PUSH! :(\n", .{});
                resetGame(allocator, &playerScore, &dealerScore, &hand, &dealer, &inHand);
                bet = 0;
            } else {
                std.debug.print("*** BLACKJACK ***\n", .{});
                money += bet * 2;
                resetGame(allocator, &playerScore, &dealerScore, &hand, &dealer, &inHand);
                bet = 0;
            }
            continue :outer;
        } else if (dealer.len == 2 and dealerScore.soft == 21 and playerScore.soft != 21 and hand.len == 2) {
            std.debug.print("*** DEALER HAS BLACKJACK!!! ***\n", .{});
            resetGame(allocator, &playerScore, &dealerScore, &hand, &dealer, &inHand);
            money -= bet;
            bet = 0;
            continue :outer;
        }
        if (playerScore.soft <= 20) {
            std.debug.print("hard score: {d}\n", .{playerScore.hard});
            std.debug.print("soft score: {d}\n", .{playerScore.soft});
        } else {
            std.debug.print("score: {d}\n", .{playerScore.hard});
        }
        std.debug.print("{s}", .{menu});
        const input = (try nextLine(stdin.reader(), &buf)).?;
        if (std.mem.eql(u8, input, "q") == true) {
            quit = true;
            break;
        }
        if (std.mem.eql(u8, input, "1") == true or
            std.mem.eql(u8, input, "hit") == true or
            std.mem.eql(u8, input, "Hit") == true)
        {
            i = 0;
            try deal(allocator, &inHand, &hand);
            playerScore.soft = 0;
            playerScore.hard = 0;
            calcHand(&hand, &playerScore);
            printHand(&hand, true);
            if (playerScore.hard > 21) {
                std.debug.print("bust.\n", .{});
                resetGame(allocator, &playerScore, &dealerScore, &hand, &dealer, &inHand);
                money -= bet;
                bet = 0;
                continue :outer;
            }
            if (playerScore.soft == 21 or playerScore.hard == 21) {
                std.debug.print("YOU GOT 21!\n", .{});
                std.debug.print("YOU WIN!!!\n", .{});
                resetGame(allocator, &playerScore, &dealerScore, &hand, &dealer, &inHand);
                money += bet * 2;
                bet = 0;
                continue :outer;
            }
        }
        if (std.mem.eql(u8, input, "2") == true or
            std.mem.eql(u8, input, "stand") == true or
            std.mem.eql(u8, input, "Stand"))
        {
            if (playerScore.soft > playerScore.hard and playerScore.soft < 21) {
                score = playerScore.soft;
            } else {
                score = playerScore.hard;
            }
            if (dealerScore.soft > score) {
                printHand(&dealer, false);
                std.debug.print("Dealer had: {d}!\nYou Lose!!!\n", .{dealerScore.soft});
                resetGame(allocator, &playerScore, &dealerScore, &hand, &dealer, &inHand);
                money -= bet;
                bet = 0;
                continue :outer;
            }
            if (dealerScore.soft == score) {
                printHand(&dealer, false);
                std.debug.print("Dealer had: {d}!\nPUSH!!!\n", .{dealerScore.soft});
                resetGame(allocator, &playerScore, &dealerScore, &hand, &dealer, &inHand);
                bet = 0;
                continue :outer;
            }
            while (dealerScore.hard < score) {
                try deal(allocator, &inHand, &dealer);
                std.debug.print("Dealer flips a card...\n", .{});
                const dealerflip = dealer.get(dealer.len - 1);
                std.debug.print("  {c} {c}\n", .{ dealerflip.rank, dealerflip.suit });
                printHand(&dealer, false);
                dealerScore.soft = 0;
                dealerScore.hard = 0;
                calcHand(&dealer, &dealerScore);
                if (dealerScore.hard > 21) {
                    std.debug.print("Dealer busted! YOU WIN!!!\n", .{});
                    resetGame(allocator, &playerScore, &dealerScore, &hand, &dealer, &inHand);
                    money += bet * 2;
                    bet = 0;
                    continue :outer;
                }
                if (dealerScore.soft >= score) {
                    if (dealerScore.soft > dealerScore.hard and dealerScore.soft < 21) {
                        dealerFinal = dealerScore.soft;
                    } else {
                        dealerFinal = dealerScore.hard;
                    }
                    if (dealerFinal > score) {
                        std.debug.print("Dealer got: {d}!\nYou Lose!!!\n", .{dealerFinal});
                        resetGame(allocator, &playerScore, &dealerScore, &hand, &dealer, &inHand);
                        dealerFinal = 0;
                        bet = 0;
                        money -= bet;
                        continue :outer;
                    }
                    if (dealerFinal == score) {
                        std.debug.print("Dealer got: {d}!\nPUSH!!!\n", .{dealerFinal});
                        resetGame(allocator, &playerScore, &dealerScore, &hand, &dealer, &inHand);
                        dealerFinal = 0;
                        bet = 0;
                        continue :outer;
                    }
                }
            }
        }
    }
}
