class_name Texts
## Todo texto visível, em português e inglês.
##
## `chave` é a versão de teclado; `chave_pad`, quando existe, é a de controle
## (a Steam exige que a tela só mostre botões de controle quando ele está em uso).

const LANGUAGES := ["pt", "en"]

const DATA := {
	"language_name": ["PORTUGUÊS", "ENGLISH"],

	"room_c_drive": ["C:\\", "C:\\"],
	"room_docs": ["C:\\Documentos", "C:\\Documents"],
	"room_downloads": ["C:\\Downloads", "C:\\Downloads"],
	"room_trash": ["C:\\Lixeira", "C:\\Trash"],
	"room_ghost": ["C:\\Lixeira\\~fantasma.tmp", "C:\\Trash\\~ghost.tmp"],
	"boss_file": ["~fantasma.tmp", "~ghost.tmp"],
	"icon_docs": ["Documentos", "Documents"],
	"icon_downloads": ["Downloads", "Downloads"],
	"icon_trash": ["Lixeira", "Trash"],

	"hud_life": ["VIDA", "HP"],
	"hud_sniff": ["FARO", "SNIFF"],
	"hud_time": ["TEMPO %02d", "TIME %02d"],
	"hud_bugs": ["BUGS %d", "BUGS %d"],

	"hint_side": [
		"A/D anda · Espaço pula · J atira · Shift fareja · Tab mapa · Esc pausa",
		"A/D move · Space jump · J shoot · Shift sniff · Tab map · Esc pause",
	],
	"hint_side_pad": [
		"A pula · X atira · LT fareja · View mapa · Menu pausa",
		"A jump · X shoot · LT sniff · View map · Menu pause",
	],
	"hint_arena": [
		"WASD anda · mouse mira · clique ou J atira · K dash",
		"WASD move · mouse aim · click or J shoot · K dash",
	],
	"hint_arena_pad": [
		"Analógico esq. anda · dir. mira · RT atira · B dash",
		"Left stick move · right stick aim · RT shoot · B dash",
	],

	"boss_intro": [
		"ARQUIVO FANTASMA\nFareje para torná-lo sólido, ou espere ele bater.",
		"GHOST FILE\nSniff to make it solid, or wait for it to crash.",
	],
	"boss_copies": [
		"O arquivo criou cópias.\nAgora só o faro acerta o original.",
		"The file made copies.\nOnly sniffing can hit the original now.",
	],
	"boss_need_sniff": [
		"O tiro atravessa. Segure Shift e atire no original.",
		"Shots pass through. Hold Shift and shoot the original.",
	],
	"boss_need_sniff_pad": [
		"O tiro atravessa. Segure LT e atire no original.",
		"Shots pass through. Hold LT and shoot the original.",
	],
	"wall_smells": [
		"Esta parede cheira estranho.\nSegure Shift para farejar.",
		"This wall smells odd.\nHold Shift to sniff.",
	],
	"wall_smells_pad": [
		"Esta parede cheira estranho.\nSegure LT para farejar.",
		"This wall smells odd.\nHold LT to sniff.",
	],
	"wall_found": ["PASSAGEM REVELADA", "PASSAGE REVEALED"],
	"health_full": ["Vida cheia: o patch fica para depois.", "Full health: the patch stays for later."],
	"hold_restart": ["Segure R para reiniciar do ponto de restauração", "Hold R to restart from the restore point"],
	"hold_restart_pad": ["Use Menu para reiniciar do ponto de restauração", "Use Menu to restart from the restore point"],
	"arena_zones": ["Setores marcados vão corromper. Saia de cima!", "Marked sectors will corrupt. Step off them!"],
	"boss_down": ["ARQUIVO FANTASMA EXCLUÍDO\nregião limpa, saída aberta", "GHOST FILE DELETED\nregion clean, exit open"],
	"got_health": ["+1 VIDA", "+1 HP"],
	"got_dash": ["DASH INSTALADO · K ou C\natravessa lasers e tiros", "DASH INSTALLED · K or C\ngoes through lasers and shots"],
	"got_dash_pad": ["DASH INSTALADO · B\natravessa lasers e tiros", "DASH INSTALLED · B\ngoes through lasers and shots"],
	"got_restore": ["PONTO DE RESTAURAÇÃO CRIADO", "RESTORE POINT CREATED"],
	"region_clean": ["Região limpa.", "Region clean."],
	"save_failed": ["NÃO FOI POSSÍVEL SALVAR O PROGRESSO", "COULD NOT SAVE YOUR PROGRESS"],
	"arena_won": ["PROCESSO CONCLUÍDO\n\nVoltando para a região...", "PROCESS COMPLETE\n\nReturning to the region..."],
	"death_side": [
		"TELA AZUL\n\nUm erro fatal ocorreu no hound.exe.\nR volta ao ponto de restauração.",
		"BLUE SCREEN\n\nA fatal error occurred in hound.exe.\nPress R to return to the restore point.",
	],
	"death_side_pad": [
		"TELA AZUL\n\nUm erro fatal ocorreu no hound.exe.\nMenu volta ao ponto de restauração.",
		"BLUE SCREEN\n\nA fatal error occurred in hound.exe.\nPress Menu to return to the restore point.",
	],
	"death_top": [
		"TELA AZUL\n\nO processo hound.exe parou de responder.\nR volta ao ponto de restauração.",
		"BLUE SCREEN\n\nhound.exe stopped responding.\nPress R to return to the restore point.",
	],
	"death_top_pad": [
		"TELA AZUL\n\nO processo hound.exe parou de responder.\nMenu volta ao ponto de restauração.",
		"BLUE SCREEN\n\nhound.exe stopped responding.\nPress Menu to return to the restore point.",
	],

	"explorer_title": ["Explorer - ", "Explorer - "],
	"explorer_legend": ["ponto de restauração · Tab fecha", "restore point · Tab closes"],
	"explorer_legend_pad": ["ponto de restauração · View fecha", "restore point · View closes"],

	"title_saved": ["Progresso salvo · volta em ", "Saved · resumes at "],
	"title_clean": [" · região limpa", " · region clean"],
	"title_bad_save": ["O save não pôde ser lido.", "The save could not be read."],
	"title_replace": ["Começar de novo substitui o progresso salvo.", "Starting over replaces your saved progress."],
	"title_keys": ["setas ou W/S escolhem · Enter confirma", "arrows or W/S choose · Enter confirms"],
	"title_keys_pad": ["direcional escolhe · A confirma · B volta", "D-pad chooses · A confirms · B back"],

	"menu_continue": ["CONTINUAR", "CONTINUE"],
	"menu_new": ["NOVO JOGO", "NEW GAME"],
	"menu_options": ["OPÇÕES", "OPTIONS"],
	"menu_quit": ["SAIR", "QUIT"],
	"menu_cancel": ["CANCELAR", "CANCEL"],
	"menu_erase": ["APAGAR E COMEÇAR", "ERASE AND START"],
	"menu_restore": ["VOLTAR AO PONTO DE RESTAURAÇÃO", "RETURN TO RESTORE POINT"],
	"menu_title": ["TELA DE TÍTULO", "TITLE SCREEN"],
	"menu_quit_game": ["SAIR DO JOGO", "QUIT GAME"],
	"menu_back": ["VOLTAR", "BACK"],
	"menu_credits": ["CRÉDITOS", "CREDITS"],
	"menu_explore": ["CONTINUAR EXPLORANDO", "KEEP EXPLORING"],

	"opt_music": ["MÚSICA", "MUSIC"],
	"opt_effects": ["EFEITOS", "EFFECTS"],
	"opt_language": ["IDIOMA", "LANGUAGE"],
	"opt_fullscreen": ["TELA CHEIA", "FULLSCREEN"],
	"opt_shake": ["TREMOR DE TELA", "SCREEN SHAKE"],
	"on": ["SIM", "ON"],
	"off": ["NÃO", "OFF"],
	"options_heading": ["Opções", "Options"],

	"pause_heading": ["Processo pausado", "Process paused"],
	"pause_saved": [
		"O progresso é salvo sozinho. Ao voltar, o cão\naparece no último ponto de restauração.",
		"Progress saves by itself. When you return, the\nhound wakes at the last restore point.",
	],
	"pause_no_save": [
		"Salvamento desligado:\nsala aberta sem passar pelo título.",
		"Saving is off:\nroom opened without the title screen.",
	],

	"ending_heading": ["Área de trabalho limpa", "Desktop clean"],
	"ending_text": [
		"Você excluiu o Arquivo Fantasma.\nEste é o fim desta versão. Obrigado por jogar!",
		"You deleted the Ghost File.\nThis is the end of this version. Thanks for playing!",
	],

	"credits_heading": ["Créditos", "Credits"],
	"credits_text": [
		"HOUND.EXE %s\n\num jogo de saulofilho\ncom o cão do scopehound\n\nfeito com Godot Engine\ncopyright Juan Linietsky, Ariel Manzur\ne colaboradores do Godot Engine\n\nlicenças: THIRD_PARTY_NOTICES.txt",
		"HOUND.EXE %s\n\na game by saulofilho\nstarring the scopehound hound\n\nmade with Godot Engine\ncopyright Juan Linietsky, Ariel Manzur\nand Godot Engine contributors\n\nlicenses: THIRD_PARTY_NOTICES.txt",
	],
}


static func lookup(key: String, language: String, pad: bool) -> String:
	var index := maxi(LANGUAGES.find(language), 0)
	if pad and DATA.has(key + "_pad"):
		key += "_pad"
	return DATA[key][index]
