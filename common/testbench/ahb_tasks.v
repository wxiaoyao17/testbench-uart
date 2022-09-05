parameter HCLK_PERIOD       = 10;
parameter UARTCLK_PERIOD    = 125;

reg                 hclk;
reg                 hresetn;

reg                 uartclk;
reg                 uartresetn;

reg [11:0]          haddr;
reg                 hwrite;
reg [1:0]           htrans;
reg [31:0]          hwdata;
reg                 hsel;
reg [2:0]           hsize;

wire [31:0]         hrdata;
wire                hreadyout;

assign reset = hresetn;

assign baud_clk = u_ahb_async_uart.u_uart_uartclk.baud_tick;

initial begin
    hclk = 1'b0;
    hresetn = 1'b0;
    hsel = 1'b0;
    htrans = 2'b00;
    hwrite = 1'b0;
    hsize = 3'h0;
    haddr = 12'h0;
    hwdata = 32'h0;
    uartclk = 1'b0;
    uartresetn = 1'b0;
    # 125;
    hresetn = 1;
    uartresetn = 1'b1;
end

always #(HCLK_PERIOD / 2)       hclk        = ~hclk;
always #(UARTCLK_PERIOD / 2)    uartclk     = ~uartclk;

task bus_write;
    input [11:0] addr;
    input [31:0] wdata;
    begin
        @(posedge hclk);
        #1;
        hsel    = 1'b1;
        htrans  = 2'b10;
        hwrite  = 1'b1;
        haddr   = addr;
        hwdata  = wdata;
        @(posedge hclk);
        #1;
        wait(hreadyout);
        @(posedge hclk);
        #1;
        hsel    = 1'b0;
        htrans  = 2'b00;
        haddr   = 32'h0;
    end
endtask

task bus_read;
    input  [11:0] addr;
    output [31:0] rdata;
    begin
        @(posedge hclk);
        #1;
        hsel    = 1'b1;
        htrans  = 2'b10;
        hwrite  = 1'b0;
        haddr   = addr;
        #1;
        @(posedge hclk)
        #1;
        wait(hreadyout);
        @(posedge hclk);
        rdata    = hrdata;
        hsel    = 1'b0;
        htrans  = 2'b00;
    end
endtask

ahb_async_uart u_ahb_async_uart(
    .hclk(hclk),
    .hresetn(hresetn),
    .uartclk(uartclk),
    .uartresetn(uartresetn),
    .hsel(hsel),
    .htrans(htrans),
    .hready(hreadyout),
    .hwrite(hwrite),
    .haddr(haddr),
    .hwdata(hwdata),
    .hsize(hsize),
    .hreadyout(hreadyout),
    .hresp(),
    .hrdata(hrdata),
    .tx_int(),
    .rx_int(),
    .rx(rx),
    .tx(tx)
);
