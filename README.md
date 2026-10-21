# Auctionator
### _For WoW 3.3.5a_

Auctionator is designed for casual everyday auction house users. Auctionator makes the auction house easier to use, by presenting auction house listings clearly and succinctly, and by eliminating the tedium involved in posting and managing auctions.
##### Version: `3.1.6`
##### Original author: `Zirco`

## Contents

| Folder | Add-on |
|---|---|
| `Auctionator` | Auctionator 3.1.6, based on 3.1.5 by Zirco |
| `AuctionatorMiniFeatures` | Auctionator MiniFeatures 5.4v2 by ckaotik, an optional extra that requires Auctionator |

## Changes from stock 3.1.5

- **Shopping Lists options page:** the list box keeps its 180px width. On 3.3.5 its original anchors stretched it across the page, and its rows covered the Delete, Edit and Rename buttons so they couldn't be clicked.
- **Shopping list Edit window** (Edit, Import, Export): can be dragged and has a close button.
- **Shopping lists protected from other add-ons:** Auctionator keeps its own reference to the shopping list class. It repairs the lists before using them and restores the global `Atr_SList` if another add-on has replaced it. Without this, the first search fails with `attempt to call method 'FindItemIndex' (a nil value)`.
- **Bulk buying:** after you finish buying at one price, the Buy popup stays open and loads the next cheapest auction you can buy, with its new price. The popup shows how many stacks and items you have bought so far and the gold spent. Cancel becomes **Done**. Prices that sell out before you buy them are skipped. When nothing is left, the popup closes with a summary. Also fixes Auctionator removing too many listings from the results after buying at one price across several pages.
- **Auction median tooltip line:** the median of an item's lowest price across its last 15 full scans, shown under the **Auction** line. Holding Shift shows the stack price, like the other lines. The prices are saved per realm and faction in `AUCTIONATOR_MEAN_PRICE_DATABASE`. They're cleared along with the full scan database, and dropped when Auctionator prunes the item from its scan database. Run a full scan to start collecting prices.
- **Buy-tab stat filters:** add `+stat` parts to a compound search (for example `+agi`, `+crit`) to keep only items whose tooltip carries that stat. The tooltip is read rather than `GetItemStats`, so random suffixes and gems count. English tooltips only (`AuctionatorStats.lua`).
- **Sort by stat value:** a search with `+stat` parts lists the highest total first. A header button named after the stats (for example "Agi+Crit") toggles high/low, ties go cheapest first, and each row shows its total after the item name.
- **DragonUI look:** with DragonUI loaded, the auction house takes its portrait border, rock and marble backgrounds, red buttons, retail tabs and sort headings (`AuctionatorDragonUI.lua`). Without DragonUI the file does nothing.
- **Old price entries:** 2.x price entries in the scan database are converted at startup instead of failing.

## Install

Copy both folders into `World of Warcraft/Interface/AddOns/`. `AuctionatorMiniFeatures` is optional.

Not ported from the old 2.6.8 version of this repo: the fix for the full scan hanging when some item names had not loaded from the server. The 2.6.8 version is in the git history.
