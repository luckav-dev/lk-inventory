<script lang="ts">
  import { lootAllDrops } from '../lib/actions';
  import { clampPercent, formatWeight } from '../lib/format';
  import { activePlayerSlot, getTotalWeight, isBusy, leftInventory, inventoryLayout } from '../stores/state';
  import type { Inventory } from '../types';
  import InventorySlot from './InventorySlot.svelte';
  import ClothingPanel from './ClothingPanel.svelte';
  import backpackIcon from '../../assets/Icon2@2x.png';

  export let inventory: Inventory;
  export let side: 'left' | 'right' = 'left';

  $: isStacked = $inventoryLayout === 'stacked-right';
  $: isPlayer = inventory.type === 'player';
  $: hotbarItems = isPlayer && !isStacked ? inventory.items.slice(0, 5) : [];
  $: gridItems = isPlayer && !isStacked ? inventory.items.slice(5) : inventory.items;
  $: currentWeight = inventory.weight ?? getTotalWeight(inventory);
  $: maxWeight = inventory.maxWeight || 0;
  $: weightPercent = maxWeight ? (currentWeight / maxWeight) * 100 : 0;
  $: label = inventory.label || (side === 'left' ? 'PLAYER' : inventory.type === 'drop' ? 'SUELO' : inventory.type?.toUpperCase() || 'TARGET');
  $: cash = $leftInventory.items.find((slot) => slot.name === 'money' || slot.name === 'cash')?.count || 0;
  $: bank = $leftInventory.items.find((slot) => slot.name === 'bank')?.count || 0;
  $: groupRank = inventory.groups ? Math.max(...Object.values(inventory.groups).map(Number).filter(Number.isFinite)) : undefined;
</script>

<section class={`inventory-panel ${side}-inventory-panel`} style:pointer-events={$isBusy ? 'none' : 'auto'}>
  <div class={`inventory-header ${side === 'left' ? 'player-header' : 'target-header'}`}>
    <div class="profile-info">
      {#if side === 'left'}
        <span class="profile-backpack-icon" style="-webkit-mask-image: url({backpackIcon}); mask-image: url({backpackIcon});"></span>
        <div class="profile-text-group">
          <span class="profile-name">{label}</span>
          <span class="profile-id">#{inventory.id}</span>
        </div>
      {:else}
        <span class="profile-name">{label}</span>

        {#if inventory.type === 'shop'}
          <div class="shop-currencies">
            <span class="currency cash"><span class="lbl">EFECTIVO:</span> ${cash.toLocaleString('en-US')}</span>
            <span class="currency bank"><span class="lbl">BANCO:</span> ${bank.toLocaleString('en-US')}</span>
          </div>
        {/if}

        {#if inventory.type === 'stash'}
          <div class="stash-badges">
            <span class="badge shared-badge">COMPARTIDO</span>
            {#if groupRank !== undefined}
              <span class="badge rank-badge">LVL {groupRank}</span>
            {/if}
          </div>
        {/if}

        {#if inventory.type === 'drop'}
          <button class="loot-all-btn" type="button" on:click={lootAllDrops}>RECOGER TODO</button>
        {/if}
      {/if}
    </div>

    {#if maxWeight && inventory.type !== 'shop' && inventory.type !== 'crafting'}
      <div class="weight-bar-wrapper">
        <div class="weight-bar-track">
          <div class="weight-bar-fill" style={`width: ${clampPercent(weightPercent)}%;`}></div>
        </div>
        <div class="weight-text">
          <span>{formatWeight(currentWeight)}</span>
          <span class="weight-max">/ {formatWeight(maxWeight)}</span>
        </div>
      </div>
    {/if}
  </div>

  <div class={isPlayer ? 'left-grid-row' : 'right-grid-row'}>
    {#if isPlayer && !isStacked}
      <ClothingPanel />
      <div class="hot-bar" aria-label="Accesos rapidos">
        {#each hotbarItems as hotbarItem (hotbarItem.slot)}
          <div class="hotbar-row-div">
            <div class={`hotbar-icon-badge ${$activePlayerSlot === hotbarItem.slot ? 'first active' : 'other'}`}><h3 class="slot-value">{hotbarItem.slot}</h3></div>
            <InventorySlot inventory={inventory} item={hotbarItem} />
          </div>
        {/each}
      </div>
    {:else if isPlayer}
      <ClothingPanel />
    {/if}

    <div class={`inventory-grid-scroll ${side}-grid-scroll`}>
      <div class={side === 'left' ? 'box' : inventory.type === 'glovebox' ? 'box2 glovebox-grid' : 'box2'} role="grid">
        {#each gridItems as slot (slot.slot)}
          <InventorySlot inventory={inventory} item={slot} />
        {/each}
      </div>
    </div>
  </div>
</section>
