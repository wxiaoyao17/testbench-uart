`timescale 1ns/10ps

module  tb_uart ();

    `include "uart_const_pkg.v"

    reg [128*8-1:0]     device_msg;
    reg                 device_req;

    wire                tx;
    wire                rx;
    wire                tx_int;
    wire                rx_int;
    wire                baud_clk;
    wire                device_done;
    wire                reset;

//---------------------------------------------
// initialization
//---------------------------------------------

initial begin
    device_req = 1'b0;
end

initial begin
    $fsdbDumpfile("uart.fsdb");
    $fsdbDumpvars(0, "+mda");
end

//---------------------------------------------
// testcases called
//---------------------------------------------

`ifdef  tx_hello
  `include "tx_hello.v"
`endif

`ifdef  rx_hello
  `include "rx_hello.v"
`endif

//---------------------------------------------
// apb or ahb bus task selected
//---------------------------------------------

`ifdef ahb
    `include "ahb_tasks.v"
`else
    `include "apb_tasks.v"
`endif

//---------------------------------------------
// common task definition
//---------------------------------------------

task controller_send;
    input   [128*8-1:0]  message;
    reg     [31:0]      read_data;
    begin
        while (message[128*8-1:128*8-8] == 8'h0) begin
            message = message << 8;
        end
        $write("%t UART controller sends: ", $time);
        while (!message[128*8-1:128*8-8] == 8'h0) begin
            bus_read(UART_STAT_OFFSET, read_data);
            while (read_data[0]) begin
                bus_read(UART_STAT_OFFSET, read_data);
            end
            bus_write(UART_STAT_OFFSET, message[128*8-1:128*8-8]);
            $write("%s", message[128*8-1:128*8-8]);
            message = message << 8;
        end
    end
endtask

task device_send;
    input   [128*8-1:0]  message;
    begin
        device_msg = message;
        device_req = 1'b1;
        @(posedge baud_clk);
        device_req = 1'b0;
        wait(device_done);
    end
endtask

//---------------------------------------------
// modules instantiated
//---------------------------------------------

uart_capture u_uart_capture(
    .RESETn(reset),
    .CLK(baud_clk),
    .RXD(tx),
    .SIMULATIONEND()
);

uart_launch u_uart_launch(
    .RESETn(reset),
    .CLK(baud_clk),
    .MSG(device_msg),
    .REQ(device_req),
    .DONE(device_done),
    .TXD(rx)
);

endmodule
