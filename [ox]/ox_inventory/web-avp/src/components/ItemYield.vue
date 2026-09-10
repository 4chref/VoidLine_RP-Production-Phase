<template>
    <div class="item-yield-parent">
        <TransitionGroup enter-active-class="animate__animated animate__fadeIn animate__faster"
            leave-active-class="animate__animated animate__fadeOut animate__faster">
            <div class="yield-entry" :class="{ 'is-removed': a.kind === 'ui_removed' }" :key="a.uniqueId"
                v-for="a in yieldStore.yields">
                <div class="yield-header">{{ headerFor(a.kind) }}</div>

                <div v-if="!a.iData.isStackable" class="yield-name">{{ a.iData.formatName }}</div>
                <div v-else class="yield-name">
                    {{ a.quantity }}x {{ a.iData.formatName }}
                </div>

                <div class="yield-img-content">
                    <div :style="{
                        backgroundImage: `url(../images/${a.item}.png)`
                    }" class="yield-img"></div>
                </div>
            </div>
        </TransitionGroup>
    </div>
</template>

<script lang="ts" setup>
import { useYieldStore } from '../store/yield.store';

const yieldStore = useYieldStore();

// ox tags each notification with its own locale key. AVP only ever said
// "New Item" because its backend only notified on pickup.
const headerFor = (kind: string) => {
    if (kind === 'ui_removed') return 'Removed';
    if (kind === 'ui_equipped') return 'Equipped';
    if (kind === 'ui_holstered') return 'Holstered';
    return 'New Item';
};

</script>

<style lang="scss" scoped>

$ENTRY_HEIGHT: 3.5vw;
$IMAGE_SIZE: 3vw;

.item-yield-parent {
    position: absolute;
    color: white;
    right: 0.2%;
    top: 20%;
    max-height: 25vw;
    display: flex;
    flex-direction: column;
    overflow: hidden;

    .yield-entry {
        position: relative;
        height: $ENTRY_HEIGHT;
        margin: .25vw 0;
        display: flex;
        align-items: center;
        justify-content: space-between;
        background: linear-gradient(90deg, transparent, rgba(50, 50, 50, .75) 75%);

        // Removals read the same but warmer, so a loss is distinguishable at a
        // glance without breaking the AVP look.
        &.is-removed {
            background: linear-gradient(90deg, transparent, rgba(70, 45, 45, .75) 75%);

            .yield-name {
                color: rgb(235, 190, 190);
            }

            .yield-img-content {
                background-color: rgba(90, 55, 55, .25);
            }

            .yield-img {
                filter: grayscale(0.35);
            }
        }

        .yield-header {
            position: absolute;
            font-size: .5vw;
            right: -.5vw;
            rotate: 90deg;
            color: grey;
            animation: fadeIn .5s ease;
        }

        .yield-name {
            position: relative;
            color: white;
            font-size: .85vw;
            font-variant: small-caps;
            animation: fadeInRight 2s ease;
        }

        .yield-img-content {
            position: relative;
            height: $IMAGE_SIZE;
            width: $IMAGE_SIZE;
            margin: 0 1.5vw;
            display: flex;
            justify-content: center;
            align-items: center;
            animation: bounceIn 1s ease;
            border-radius: .25vw;
            background-color: rgba(60, 60, 60, .25);

            .yield-img {
                width: 90%;
                height: 90%;
                background-position: center;
                background-size: contain;
                background-repeat: no-repeat;
                pointer-events: none;
            }
        }
    }
}
</style>