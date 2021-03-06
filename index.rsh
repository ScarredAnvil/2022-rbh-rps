'reach 0.1';

const [ isHand, ROCK, PAPER, SCISSORS ] = makeEnum(3);
const [ isOutcome, B_WINS, DRAW, A_WINS ] = makeEnum(3);
// this provides the hand constant and outcome constants, of whih there are strictly these 3 options (enumerated for later in the code)

const winner = (handAlice, handBob) =>
  ((handAlice + (4 - handBob)) % 3);
// defines a constant "winner", using modular math

assert(winner(ROCK, PAPER) == B_WINS);
assert(winner(PAPER, ROCK) == A_WINS);
assert(winner(ROCK, ROCK) == DRAW);
// defines what the winner constant is, that is, that rock (p1), paper (p2) means p2 wins

forall(UInt, handAlice =>
  forall(UInt, handBob =>
    assert(isOutcome(winner(handAlice, handBob)))));
// winner must be valid no matter what specific value of hand

forall(UInt, (hand) =>
  assert(winner(hand, hand) == DRAW));
// if the same value is provided for both then it is a draw

const Player = {
  ...hasRandom,
  getHand: Fun([], UInt),
  seeOutcome: Fun([UInt], Null),
  informTimeout: Fun([], Null),
};
// defines the Player constant, getHand returns an integer and getOutcome recieves an integer. InformTimeout is called later in the code to avoid people leaving causing the game to stall

export const main = Reach.App(() => {
  const Alice = Participant('Alice', {
    ...Player,
    wager: UInt,
    deadline: UInt,
  });
  const Bob   = Participant('Bob', {
    ...Player,
    acceptWager: Fun([UInt], Null),
  });
  init();
// defines Alice and Bob as players, that A provides the wager and deadline, and B accepts the wager. The deadline does not need to be accepted, but that can be an extension. Speed RPS!
 
  const informTimeout = () => {
    each([Alice, Bob], () => {
      interact.informTimeout();
    });
  };
// this informs the players of the deadline
  Alice.only(() => {
    const wager = declassify(interact.wager);
    const deadline = declassify(interact.deadline);
  });
  Alice.publish(wager, deadline)
    .pay(wager);
  commit();
// only A performs these, publishes the wager and deadline info, pays wager, commits

  Bob.only(() => {
    interact.acceptWager(wager);
  });
  Bob.pay(wager)
    .timeout(relativeTime(deadline), () => closeTo(Alice, informTimeout));
// only B performs these, accepts wager, pays wager, and times out if no response

  var outcome = DRAW;
  invariant( balance() == 2 * wager && isOutcome(outcome) );
  while ( outcome == DRAW ) {
    commit();
// defines a loop so that while it's a DRAW the game keeps repeating

    Alice.only(() => {
      const _handAlice = interact.getHand();
      const [_commitAlice, _saltAlice] = makeCommitment(interact, _handAlice);
      const commitAlice = declassify(_commitAlice);
    });
    Alice.publish(commitAlice)
      .timeout(relativeTime(deadline), () => closeTo(Bob, informTimeout));
    commit();
// A computes the hand, computes a commitment including a salt generated by hasRandom, declassifies the commitment, and publishes then pays the wager

    unknowable(Bob, Alice(_handAlice, _saltAlice));
    Bob.only(() => {
      const handBob = declassify(interact.getHand());
    });
    Bob.publish(handBob)
      .timeout(relativeTime(deadline), () => closeTo(Alice, informTimeout));
    commit();
// now we can assert that Bob cannot know Alice's hand, declassifies his hand, and publishes and pays the wager

    Alice.only(() => {
      const saltAlice = declassify(_saltAlice);
      const handAlice = declassify(_handAlice);
    });
    Alice.publish(saltAlice, handAlice)
      .timeout(relativeTime(deadline), () => closeTo(Bob, informTimeout));
    checkCommitment(commitAlice, saltAlice, handAlice);
// this declassifies the secret info from A, publishes the info, and then checks to make sure they match (for honest participants)

    outcome = winner(handAlice, handBob);
    continue;
  }
// end of the loop, defines the winner

  assert(outcome == A_WINS || outcome == B_WINS);
  transfer(2 * wager).to(outcome == A_WINS ? Alice : Bob);
  commit();

// asserts that is never a DRAW (since all the DRAW results are contained in the above loop), transfers the funds minus tx fees

  each([Alice, Bob], () => {
    interact.seeOutcome(outcome);
    // sends the outcome to the frontend 
  });
});
