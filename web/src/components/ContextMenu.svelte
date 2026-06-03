<script lang="ts">
  import {
    dropItem,
    giveItem,
    removeAmmo,
    removeComponent,
    useCustomButton,
    useItem,
  } from '../lib/actions';
  import { contextMenu, itemAmount, items, weaponModal } from '../stores/state';

  $: menu = $contextMenu;
  $: item = menu?.item;
  $: itemData = item?.name ? $items[item.name] : undefined;

  let panel: 'main' | 'send' = 'main';
  let contextQty = 1;
  let previousSlot: number | undefined;

  $: if (item && previousSlot !== item.slot) {
    previousSlot = item.slot;
    panel = 'main';
    contextQty = 1;
  }

  function close() {
    contextMenu.set(null);
  }

  function run(action: () => void) {
    action();
    close();
  }

  function changeQty(delta: number) {
    const max = Math.max(1, item?.count || 1);
    contextQty = Math.max(1, Math.min(max, contextQty + delta));
  }

  function submitSend() {
    if (!item) return;
    itemAmount.set(contextQty);
    run(() => giveItem(item));
  }

  function copySerial() {
    const serial = item?.metadata?.serial;
    if (serial) void navigator.clipboard?.writeText(serial);
  }

  function customLabel(button: string | { label: string }) {
    return typeof button === 'string' ? button : button.label;
  }
</script>

{#if menu && item}
  <button class="context-menu-backdrop" type="button" aria-label="Cerrar menu" on:click={close}></button>
  <div class={`context-menu ${menu.align || 'align-right'}`} style={`left: ${menu.x}px; top: ${menu.y}px;`}>
    {#if panel === 'main'}
      <div class="context-menu-main">
        <button class="context-menu-btn" data-action="use" type="button" on:click={() => run(() => useItem(item))}>USAR</button>
        <button class="context-menu-btn" data-action="send" type="button" on:click={() => (panel = 'send')}>ENVIAR</button>

        {#if item.name.startsWith('WEAPON_')}
          <button class="context-menu-btn" data-action="modify" type="button" on:click={() => run(() => weaponModal.set({ item, slot: item.slot }))}>MODIFICAR</button>
        {/if}

        <button class="context-menu-btn" data-action="destroy" type="button" on:click={() => run(() => dropItem(item))}>DESTRUIR</button>

        {#if item.metadata?.ammo > 0}
          <button class="context-menu-btn" data-action="ammo" type="button" on:click={() => run(() => removeAmmo(item))}>QUITAR MUNICION</button>
        {/if}

        {#if item.metadata?.serial}
          <button class="context-menu-btn" data-action="serial" type="button" on:click={() => run(copySerial)}>COPIAR SERIE</button>
        {/if}

        {#if item.metadata?.components?.length}
          <div class="context-menu-group">ACCESORIOS</div>
          {#each item.metadata.components as component}
            <button class="context-menu-btn" data-action="component" type="button" on:click={() => run(() => removeComponent(item, component))}>
              QUITAR {$items[component]?.label || component}
            </button>
          {/each}
        {/if}

        {#if itemData?.buttons?.length}
          <div class="context-menu-group">ACCIONES</div>
          {#each itemData.buttons as button, index}
            <button class="context-menu-btn" data-action="custom" type="button" on:click={() => run(() => useCustomButton(item, index))}>{customLabel(button)}</button>
          {/each}
        {/if}
      </div>
    {:else}
      <div class="context-menu-send">
        <div class="send-qty-selector">
          <button class="qty-btn minus" type="button" on:click={() => changeQty(-1)}>-</button>
          <span class="qty-val">{contextQty}</span>
          <button class="qty-btn plus" type="button" on:click={() => changeQty(1)}>+</button>
        </div>
        <button class="context-menu-btn btn-action-submit" data-action="submit-send" type="button" on:click={submitSend}>ENVIAR</button>
        <button class="context-menu-btn btn-action-cancel" data-action="cancel-send" type="button" on:click={() => (panel = 'main')}>CANCELAR</button>
      </div>
    {/if}
  </div>
{/if}
