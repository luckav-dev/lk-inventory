<script lang="ts">
  import { getItemLabel, getItemUrl, isSlotWithItem, notifications } from '../stores/state';
</script>

<div class="notifications">
  {#each $notifications as notification (notification.id)}
    <div class={`notification ${notification.kind}`}>
      {#if isSlotWithItem(notification.item)}
        <img src={getItemUrl(notification.item)} alt="" />
      {/if}
      <div>
        <strong>{getItemLabel(notification.item) || 'Inventario'}</strong>
        <span>{notification.count ? `${notification.count}x ` : ''}{notification.kind === 'ui_removed' ? 'retirado' : notification.kind === 'error' ? 'rechazado' : 'anadido'}</span>
      </div>
    </div>
  {/each}
</div>
