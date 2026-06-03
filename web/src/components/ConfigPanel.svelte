<script lang="ts">
  import { configVisible, inventoryVisible, inventoryLayout } from '../stores/state';
  import { fetchNui } from '../lib/nui';
  import { applyThemeColor } from '../lib/theme';

  const presets = [
    { name: 'Rojo (Defecto)', color: '#e42a2d' },
    { name: 'Naranja', color: '#ea580c' },
    { name: 'Amarillo', color: '#eab308' },
    { name: 'Verde', color: '#16a34a' },
    { name: 'Cian', color: '#0891b2' },
    { name: 'Azul', color: '#2563eb' },
    { name: 'Morado', color: '#7c3aed' },
    { name: 'Rosa', color: '#db2777' },
  ];

  let selectedColor = localStorage.getItem('inventory-accent') || '#e42a2d';
  let selectedLayout = $inventoryLayout;

  function selectColor(color: string) {
    selectedColor = color;
    applyThemeColor(color);
  }

  function selectLayout(layout: 'classic' | 'stacked-right') {
    selectedLayout = layout;
    inventoryLayout.set(layout);
  }

  function saveAndClose() {
    localStorage.setItem('inventory-accent', selectedColor);
    localStorage.setItem('inventory-layout', selectedLayout);
    configVisible.set(false);
    inventoryVisible.set(false);
    void fetchNui('closeConfig');
  }
</script>

<div class="config-modal-backdrop">
  <div class="config-modal-container">
    <div class="config-modal-header">
      <h2>CONFIGURACIÓN DE TEMA</h2>
      <p>Personaliza el color de acento de tu interfaz</p>
    </div>

    <div class="config-modal-body">
      <div class="color-section">
        <h3>COLORES PREDEFINIDOS</h3>
        <div class="color-presets-grid">
          {#each presets as preset}
            <button
              class="preset-btn"
              class:active={selectedColor.toLowerCase() === preset.color.toLowerCase()}
              style:background-color={preset.color}
              type="button"
              on:click={() => selectColor(preset.color)}
              aria-label={preset.name}
            >
              {#if selectedColor.toLowerCase() === preset.color.toLowerCase()}
                <span class="check-mark">✓</span>
              {/if}
            </button>
          {/each}
        </div>
      </div>

      <div class="custom-color-section">
        <h3>COLOR PERSONALIZADO</h3>
        <div class="custom-color-input-wrapper">
          <input
            type="color"
            id="custom-color-picker"
            value={selectedColor}
            on:input={(e) => selectColor(e.currentTarget.value)}
          />
          <input
            type="text"
            class="hex-text-input"
            value={selectedColor.toUpperCase()}
            on:input={(e) => selectColor(e.currentTarget.value)}
            maxlength="7"
          />
        </div>
      </div>

      <div class="layout-section">
        <h3>DISEÑO DE INTERFAZ</h3>
        <div class="layout-options">
          <button
            class="layout-option-btn"
            class:active={selectedLayout === 'classic'}
            type="button"
            on:click={() => selectLayout('classic')}
          >
            CLÁSICO
          </button>
          <button
            class="layout-option-btn"
            class:active={selectedLayout === 'stacked-right'}
            type="button"
            on:click={() => selectLayout('stacked-right')}
          >
            COMPACTO
          </button>
        </div>
      </div>
    </div>

    <div class="config-modal-footer">
      <button class="save-btn" type="button" on:click={saveAndClose}>
        GUARDAR Y CERRAR
      </button>
    </div>
  </div>
</div>
