<template>
    <div class="newtooltip-attachment-entry">
    </div>
</template>

<script lang="ts" setup>
const props = defineProps({
    inventoryUniqueId: {
        type: String,
        required: true
    },
    itemHash: {
        type: String,
        required: true
    }
});
</script>
