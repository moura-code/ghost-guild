class_name TraitDef
extends RefCounted
## What a Legend does to the fight, beyond multiplying numbers (spec §6.1: "a
## trait from the dominant archetype -- a Poison Legend makes the hero's Poison
## cards apply +1 stack").
##
## A trait is keyed to a **card tag**, not to a Legend: `Legends.dominant_tag`
## already reduces a whole cycle's decks to the one thing they were mostly made
## of, and the trait is what that thing is worth for ever after. So the guild
## that spent a cycle on Poison gets a Poison trait, and the trait is a reason
## to have played that way rather than a reward for having done so.
##
## Deliberately narrow. Each one boosts one kind of effect on cards that carry
## its tag, so a trait is legible on the card you are holding -- you can see
## which of your cards it applies to -- rather than being a hidden global
## modifier the player has to take on faith.

## The effects a trait may have, each one a place the resolver already
## computes a number.
const OPS: Array[String] = [
	"status",   # +N stacks when a tagged card applies a status
	"damage",   # +N damage on a tagged card
	"block",    # +N block from a tagged card
	"draw",     # +N cards from a tagged card that draws
]

var id: String = ""
## The card tag this reads off. One trait per tag, and every tag the cards use
## must have one, or a guild's whole cycle buys nothing -- `slice_content_test`
## asserts exactly that.
var tag: String = ""
var name_key: String = ""
var text_key: String = ""
var op: String = ""
var amount: int = 0


static func from_dict(d: Dictionary) -> TraitDef:
	var t := TraitDef.new()
	t.id = String(d.get("id", ""))
	t.tag = String(d.get("tag", ""))
	t.name_key = String(d.get("name", ""))
	t.text_key = String(d.get("text", ""))
	t.op = String(d.get("op", ""))
	t.amount = int(d.get("amount", 0))
	return t
