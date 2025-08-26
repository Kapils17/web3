;; CharityDistribution DAO
;; A transparent charity platform with community voting on fund allocation and impact tracking

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-unauthorized (err u101))
(define-constant err-invalid-amount (err u102))
(define-constant err-proposal-not-found (err u103))
(define-constant err-already-voted (err u104))
(define-constant err-voting-closed (err u105))
(define-constant err-insufficient-funds (err u106))

;; Data variables
(define-data-var proposal-count uint u0)
(define-data-var total-funds uint u0)
(define-data-var min-voting-threshold uint u10) ;; Minimum votes needed for proposal to pass

;; Data structures
(define-map proposals
  uint
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    recipient: principal,
    amount: uint,
    votes-for: uint,
    votes-against: uint,
    voting-deadline: uint,
    executed: bool,
    proposer: principal
  })

(define-map user-votes
  {proposal-id: uint, voter: principal}
  {vote: bool, timestamp: uint})

;; Function 1: Create Proposal
;; Allows community members to propose charity funding allocations
(define-public (create-proposal 
    (title (string-ascii 100))
    (description (string-ascii 500))
    (recipient principal)
    (amount uint)
    (voting-duration uint))
  (let 
    ((proposal-id (+ (var-get proposal-count) u1))
     (deadline (+ stacks-block-height voting-duration)))
    (begin
      (asserts! (> amount u0) err-invalid-amount)
      (asserts! (<= amount (var-get total-funds)) err-insufficient-funds)
      (asserts! (> voting-duration u0) err-invalid-amount)
      
      ;; Create the proposal
      (map-set proposals proposal-id
        {
          title: title,
          description: description,
          recipient: recipient,
          amount: amount,
          votes-for: u0,
          votes-against: u0,
          voting-deadline: deadline,
          executed: false,
          proposer: tx-sender
        })
      
      ;; Update proposal count
      (var-set proposal-count proposal-id)
      
      ;; Print proposal creation event
      (print {
        event: "proposal-created",
        proposal-id: proposal-id,
        title: title,
        amount: amount,
        recipient: recipient,
        deadline: deadline
      })
      
      (ok proposal-id))))

;; Function 2: Vote on Proposal
;; Allows community members to vote on funding proposals
(define-public (vote-on-proposal (proposal-id uint) (vote-for bool))
  (let 
    ((proposal (unwrap! (map-get? proposals proposal-id) err-proposal-not-found))
     (voter-key {proposal-id: proposal-id, voter: tx-sender}))
    (begin
      ;; Check if voting is still open
      (asserts! (< stacks-block-height (get voting-deadline proposal)) err-voting-closed)
      
      ;; Check if user hasn't voted yet
      (asserts! (is-none (map-get? user-votes voter-key)) err-already-voted)
      
      ;; Record the vote
      (map-set user-votes voter-key
        {
          vote: vote-for,
          timestamp: stacks-block-height
        })
      

      ;; Print voting event
      (print {
        event: "vote-cast",
        proposal-id: proposal-id,
        voter: tx-sender,
        vote-for: vote-for,
        timestamp: stacks-block-height
      })
      
      (ok true))))

;; Read-only functions
(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id))

(define-read-only (get-proposal-count)
  (var-get proposal-count))

(define-read-only (get-total-funds)
  (var-get total-funds))

(define-read-only (get-user-vote (proposal-id uint) (voter principal))
  (map-get? user-votes {proposal-id: proposal-id, voter: voter}))

;; Deposit funds to the DAO (for demonstration)
(define-public (deposit-funds (amount uint))
  (begin
    (asserts! (> amount u0) err-invalid-amount)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set total-funds (+ (var-get total-funds) amount))
    (print {event: "funds-deposited", amount: amount, depositor: tx-sender})
    (ok true)))