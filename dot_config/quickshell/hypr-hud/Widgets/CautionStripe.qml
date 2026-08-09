import QtQuick

import qs.Commons

// Výstražné šrafy — diagonální pruhy à la staveniště. Používá se jako 6px pás
// pod horní hranou panelu a jako 8px svislý pruh na levé hraně dlaždice,
// která je v „pozorném" stavu (DND zapnuté, mute, žádný přehrávač).
Item {
    id: stripe

    property color color: Style.warn
    property real  stripeOpacity: 0.45
    property int   pitch: 14          // rozteč pruhů
    property int   thickness: 6       // šířka jednoho pruhu

    clip: true

    Repeater {
        // +height, aby pruhy pokryly i to, co se rotací vysune za levý okraj
        model: Math.max(1, Math.ceil((stripe.width + stripe.height) / stripe.pitch))

        Rectangle {
            required property int index

            width: stripe.thickness
            height: stripe.height * 2.4
            color: Style.withAlpha(stripe.color, stripe.stripeOpacity)
            border.width: 0
            rotation: 45
            transformOrigin: Item.Center
            x: index * stripe.pitch - stripe.height
            y: -stripe.height * 0.7
        }
    }
}
