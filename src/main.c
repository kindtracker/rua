#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv) {
  argc=argc;
  char *PathName = argv[1];
  if (PathName == NULL) {
    PathName = "main.lua";
  }

  FILE *InputFile = fopen(PathName, "r");

  int InputSize;
  fseek(InputFile, 0, SEEK_END);
  InputSize = ftell(InputFile);
  fseek(InputFile, 0, SEEK_SET);

  const char *InputBuffer = malloc(InputSize);
  fread(InputBuffer, 1, InputSize, InputFile);

  printf("%s", InputBuffer)
  return 0;
}
