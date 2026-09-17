#include <stdio.h>
#include <stdlib.h>

#include "rua.h"

int main(int argc, char **argv) {
  const char *PathName = "main.lua";

  if (argc > 1) {
    PathName = argv[1];
  }

  FILE *InputFile = fopen(PathName, "r");

  if (InputFile == NULL) {
    perror(PathName);
    return 1;
  }

  fseek(InputFile, 0, SEEK_END);
  long InputSize = ftell(InputFile);
  fseek(InputFile, 0, SEEK_SET);

  char *InputBuffer = malloc(InputSize + 1);

  if (InputBuffer == NULL) {
    fclose(InputFile);
    return 1;
  }

  fread(InputBuffer, 1, InputSize, InputFile);
  InputBuffer[InputSize] = '\0';

  fclose(InputFile);

  RuaState State = RuaNewState();

  RuaResult Result = RuaLoadString(&State, InputBuffer);
  Result = Result;

  free(InputBuffer);
  return 0;
}
