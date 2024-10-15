// ContentView.swift

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Text("Come avviare lo Screencast:")
                .font(.headline)
                .padding()

            Text("""
                1. Apri il Centro di Controllo sul tuo dispositivo.
                2. Tocca e tieni premuto il pulsante di registrazione dello schermo.
                3. Dall'elenco delle app, seleziona "ScreenCaster" (o il nome della tua app).
                4. Tocca "Avvia Trasmissione".
                """)
                .padding()
                .multilineTextAlignment(.leading)

            Text("Per interrompere lo screencast, ripeti i passaggi e tocca \"Interrompi Trasmissione\".")
                .padding()
                .multilineTextAlignment(.center)
        }
    }
}
