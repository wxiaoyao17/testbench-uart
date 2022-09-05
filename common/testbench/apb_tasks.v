parameter PCLK_PERIOD       = 10;
parameter UARTCLK_PERIOD    = 125;

reg                 pclk;
reg                 presetn;

reg                 uartclk;
reg                 uartresetn;

reg [11:0]          paddr;
reg                 pwrite;
reg                 penable;
reg [31:0]          pwdata;
reg                 psel;

wire [31:0]         prdata;
wire                pready;

assign reset = presetn;

`ifdef async
    assign baud_clk = u_apb_async_uart.u_uart_uartclk.baud_tick;
`else
    assign baud_clk = u_apb_sync_uart.baud_tick;
`endif

initial begin
    pclk = 1'b0;
    presetn = 1'b0;
    psel = 1'b0;
    penable = 1'b0;
    pwrite = 1'b0;
    paddr = 12'h0;
    pwdata = 32'h0;
    uartclk = 1'b0;
    uartresetn = 1'b0;
    # 125;
    presetn = 1'b1;
    uartresetn = 1'b1;
end

always #(PCLK_PERIOD / 2)       pclk        = ~pclk;
always #(UARTCLK_PERIOD / 2)    uartclk     = ~uartclk;

task bus_write;
    input [11:0] addr;
    input [31:0] wdata;
    begin
        @(posedge pclk);
        #1;
        psel    = 1'b1;
        penable = 1'b0;
        pwrite  = 1'b1;
        paddr   = addr;
        pwdata  = wdata;
        @(posedge pclk);
        #1;
        penable = 1'b1;
        wait(pready);
        @(posedge pclk);
        #1;
        psel    = 1'b0;
        penable = 1'b0;
        paddr   = 32'h0;
    end
endtask

task bus_read;
    input  [11:0] addr;
    output [31:0] rdata;
    begin
        @(posedge pclk);
        #1;
        psel    = 1'b1;
        penable = 1'b0;
        pwrite  = 1'b0;
        paddr   = addr;
        @(posedge pclk);
        #1;
        penable = 1'b1;
        wait(pready);
        @(posedge pclk);
        rdata   = prdata;
        #1;
        psel    = 1'b0;
        penable = 1'b0;
    end
endtask

`ifdef async
    apb_async_uart u_apb_async_uart(
        .pclk(pclk),
        .presetn(presetn),
        .uartclk(uartclk),
        .uartresetn(uartresetn),
`else
    apb_sync_uart u_apb_sync_uart(
        .pclk(pclk),
        .presetn(presetn),
`endif
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .paddr(paddr),
        .pwdata(pwdata),
        .pready(pready),
        .pslverr(),
        .prdata(prdata),
        .tx_int(tx_int),
        .rx_int(rx_int),
        .rx(rx),
        .tx(tx)
    );
