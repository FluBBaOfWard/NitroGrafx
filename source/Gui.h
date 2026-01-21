#ifndef GUI_HEADER
#define GUI_HEADER

#ifdef __cplusplus
extern "C" {
#endif

void setupGUI(void);
void enterGUI(void);
void exitGUI(void);
void nullUINormal(int key);
void nullUIDebug(int key);

void uiNullNormal(void);
void uiAbout(void);
void uiBios(void);

void setupKeyboard(void);

void ejectGame(void);
void powerOnOff(void);
void resetGame(void);

#ifdef __cplusplus
} // extern "C"
#endif

#endif // GUI_HEADER
