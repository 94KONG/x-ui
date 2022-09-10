package controller

import (
	"github.com/gin-gonic/gin"
	"net/http"
	"x-ui/web/session"
)

type BaseController struct {
}

func (a *BaseController) checkLogin(c *gin.Context) {
	if !session.IsLogin(c) {
		if isAjax(c) {
			pureJsonMsg(c, false, "Срок входа в систему истек, пожалуйста, войдите снова")
		} else {
			c.Redirect(http.StatusTemporaryRedirect, c.GetString("base_path"))
		}
		c.Abort()
	} else {
		c.Next()
	}
}
