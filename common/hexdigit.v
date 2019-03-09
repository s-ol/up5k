/** \file
 * hexdigit function
 */

function [7:0] hexdigit;
  input [3:0] x;
  begin
    hexdigit =
      x == 0 ? "0" :
      x == 1 ? "1" :
      x == 2 ? "2" :
      x == 3 ? "3" :
      x == 4 ? "4" :
      x == 5 ? "5" :
      x == 6 ? "6" :
      x == 7 ? "7" :
      x == 8 ? "8" :
      x == 9 ? "9" :
      x == 10 ? "a" :
      x == 11 ? "b" :
      x == 12 ? "c" :
      x == 13 ? "d" :
      x == 14 ? "e" :
      x == 15 ? "f" :
      "?";
  end
endfunction
