//---------------------------------------------
// Purpose : a device captures serial data
//---------------------------------------------
// This module stop the simulation when character 0x04 is received.
// An output called SIMULATION_END is set for 1 cycle before simulation is
// terminated to allow other testbench component like profiler (if any)
// to output reports before the simulation stop.

module uart_capture (
    input   wire      RESETn,           // Power on reset
    input   wire      CLK,              // Clock (baud rate)
    input   wire      RXD,              // Received data
    output  wire      SIMULATIONEND    // Simulation end indicator
);

    reg  [8:0]      rx_shift_reg;
    wire [8:0]      nxt_rx_shift;
    reg  [6:0]      string_length;
    reg  [7:0]      tube_string[127:0];
    reg  [7:0]      text_char;
    integer         i;
    reg             nxt_end_simulation;
    reg             reg_end_simulation;
    wire            char_received;

    // Receive shift register
    assign nxt_rx_shift  = {RXD, rx_shift_reg[8:1]};
    assign char_received = (rx_shift_reg[0] == 1'b0);

    always @(posedge CLK or negedge RESETn)
    begin
        if (~RESETn)
            rx_shift_reg <= {9{1'b1}};
        else
            if (rx_shift_reg[0] == 1'b0) // Start bit reach bit[0]
                rx_shift_reg <= {9{1'b1}};
            else
                rx_shift_reg <= nxt_rx_shift;
    end

    // Message display
    always @(posedge CLK or negedge RESETn)
    begin: p_tube
        if (~RESETn)
        begin
            string_length = 7'b0;
            nxt_end_simulation <= 1'b0;
            for (i = 0; i <= 127; i = i + 1) begin
                tube_string[i] = 8'h00;
            end
        end
        else
            if (char_received)
            begin
                if (rx_shift_reg[8:1] == 8'h1B)
                begin
                    // Escape code, or in escape code mode
                    // Data receive can be command, aux ctrl data
                    // Ignore this data
                end
                else if (rx_shift_reg[8:1] == 8'h04) // Stop simulation if 0x04 is received
                    nxt_end_simulation <= 1'b1;
                else if ((rx_shift_reg[8:1] == 8'h0d) | (rx_shift_reg[8:1] == 8'h0A))
                // New line
                begin
                    tube_string[string_length] = 8'h00;
                    $write("%t UART device captures: ", $time);

                    for (i = 0; i <= string_length; i = i + 1)
                    begin
                        text_char = tube_string[i];
                        $write("%s", text_char);
                    end

                    $write("\n");
                    string_length = 7'b0;
                end
                else
                begin
                    tube_string[string_length] = rx_shift_reg[8:1];
                    string_length = string_length + 1;
                    if (string_length > 79) // line too long, display and clear buffer
                    begin
                        tube_string[string_length] = 8'h00;
                        $write("%t UART device captures: ", $time);

                        for (i = 0; i <= string_length; i = i + 1)
                        begin
                            text_char = tube_string[i];
                            $write("%s", text_char);
                        end

                        $write("\n");
                        string_length = 7'b0;
                    end
                end
            end
    end // p_TUBE

    // Delay for simulation end
    always @(posedge CLK or negedge RESETn)
    begin: p_sim_end
        if (~RESETn)
        begin
            reg_end_simulation <= 1'b0;
        end
        else
            reg_end_simulation <= nxt_end_simulation;
            if (reg_end_simulation == 1'b1)
            begin
                $write("%t UART: Test Ended\n", $time);
                $stop;
            end
    end

    assign SIMULATIONEND = nxt_end_simulation & ~reg_end_simulation;

endmodule