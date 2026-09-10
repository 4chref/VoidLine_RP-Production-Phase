<template>
    <div class="newtooltip-attachment-entry highlight" @click.prevent.left="RemoveAttachment">
        <div class="newtooltip-attachment-entry-image" :style="{
                backgroundImage: `url(../images/${attachmentName}.png)`
            }"></div>
    </div>
</template>

<script lang="ts" setup>
import { AxiosInstance } from '../plugins/axios.plugin';

const props = defineProps({
    attachmentIndex: {
        type: Number,
        required: true,
    },
    attachmentName: {
        type: String,
        required: true
    },
    itemHash: {
        type: String,
        required: true
    },
    inventoryUniqueId: {
        type: String,
        required: true
    }
});

const RemoveAttachment = () => {
    AxiosInstance.post("ITEM_REMOVE_ATTACHMENT_WEAPON", {
        attachmentIndex: props.attachmentIndex,
        itemHash: props.itemHash,
        inventoryUniqueId: props.inventoryUniqueId
    });
}
</script>