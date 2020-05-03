/*  This file is part of JT5205.
    JT5205 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT5205 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT5205.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 30-10-2019 */

module jt5205(
    input                  rst,
    input                  clk,
    input                  cen /* direct_enable */,        
    input         [ 1:0]   sel,        // s pin
    input         [ 3:0]   din,
    output signed [11:0]   sound,
    // This output pin is not part of MSM5205 I/O
    // It helps integrating the system as it produces
    // a strobe
    // at the internal clock divider pace
    output reg             irq
);

wire cen_lo;        // internal clock enable signal dictated by sel bits

always @(posedge clk) irq<=cen_lo;

jt5205_timing u_timing(
    .clk    ( clk       ),
    .cen    ( cen       ),
    .sel    ( sel       ),
    .cen_lo ( cen_lo    )
);

jt5205_adpcm u_adpcm(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen_lo ( cen_lo    ),
    .cen_hf ( cen       ),
    .din    ( din       ),
    .sound  ( sound     )
);

endmodule