#include "HX711.h"

#define DOUT  A1
#define CLK  A0

HX711 balanza;

void setup() {
  Serial.begin(9600);
  balanza.begin(DOUT,CLK);
  Serial.print("Lectura del valor del ADC:  ");
  Serial.println(balanza.read());
  Serial.println("No ponga ningun  objeto sobre la balanza");
  Serial.println("Destarando...");
  balanza.set_scale( -211.9170459 ); //La escala por defecto es 1
  balanza.tare(30);  //El peso actual es considerado Tara.
  Serial.println("Coloque un peso conocido:");
  
}
/* -211917.0459 */
/*void loop() {

  Serial.print("Valor de lectura:  ");
  Serial.println(balanza.get_value(20),0);
  delay(100);
}*/

void loop() {
  Serial.print("Peso: ");
  Serial.print(balanza.get_units(1),0);
  Serial.println(" g");
  delay(50);
}
